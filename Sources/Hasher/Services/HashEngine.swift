import Foundation

// ============================================================================
// 哈希计算引擎
// ----------------------------------------------------------------------------
// 负责真正读文件、算哈希，并做了以下性能/体验优化：
//   1. 多核并行：同时处理多个文件，并发数 = CPU 核心数；
//   2. 分块读取：大文件按 8 MB 分块，不会一次性读进内存；
//   3. 单次读盘多算法：一个文件只读一遍，同时更新所有算法（见 HashPipeline）；
//   4. 支持随时停止、实时上报进度。
// ============================================================================

final class HashEngine {

    /// 线程安全的停止标志
    private let stopFlag = StopFlag()

    /// 请求停止所有正在进行的计算
    func stop() {
        stopFlag.set(true)
    }

    /// 计算一组文件的哈希
    /// - Parameters:
    ///   - files: 需要计算的文件 URL 列表
    ///   - algorithms: 用户勾选的算法列表（顺序即结果顺序）
    ///   - onProgress: 进度回调（0.0 ~ 1.0），在主线程调用
    ///   - onComplete: 完成回调（结果按输入顺序返回），在主线程调用
    func compute(files: [URL],
                 algorithms: [HashAlgorithm],
                 onProgress: @escaping (Double) -> Void,
                 onComplete: @escaping ([FileHashResult]) -> Void) {

        // 开始一次新任务前，先复位停止标志
        stopFlag.set(false)

        // 预先统计总字节数，用于计算整体进度
        let totalBytes = files.reduce(Int64(0)) { $0 + FileInfo.fileSize($1) }
        let tracker = ProgressTracker(totalBytes: totalBytes)

        // 用全局并发队列并行处理多个文件
        let queue = DispatchQueue.global(qos: .userInitiated)
        let group = DispatchGroup()
        // 信号量限制同时处理的文件数，避免线程过多互相争抢
        let semaphore = DispatchSemaphore(value: ProcessInfo.processInfo.activeProcessorCount)

        // 结果会被多个线程并发写入，所以用锁保护；
        // 记录 index 是为了最后能按“输入顺序”排序返回
        let resultsLock = NSLock()
        var collected: [(index: Int, result: FileHashResult)] = []

        for (index, file) in files.enumerated() {
            group.enter()
            queue.async { [weak self] in
                guard let self = self else {
                    group.leave()
                    return
                }

                semaphore.wait()
                defer {
                    semaphore.signal()
                    group.leave()
                }

                // 已被用户停止，直接跳过
                guard !self.stopFlag.isStopped else { return }

                guard let result = self.hashSingleFile(file, algorithms: algorithms, tracker: tracker, onProgress: onProgress) else {
                    return
                }

                resultsLock.lock()
                collected.append((index, result))
                resultsLock.unlock()
            }
        }

        // 所有文件处理完后，在主线程回调结果
        group.notify(queue: .main) {
            let results = collected.sorted { $0.index < $1.index }.map { $0.result }
            onComplete(results)
        }
    }

    /// 计算单个文件的哈希（分块读取）
    private func hashSingleFile(_ url: URL,
                                algorithms: [HashAlgorithm],
                                tracker: ProgressTracker,
                                onProgress: @escaping (Double) -> Void) -> FileHashResult? {
        // 以读取模式打开文件
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        // 创建一个流水线，一次读盘同时计算多个算法
        let pipeline = HashPipeline(algorithms: algorithms)
        let chunkSize = 8 * 1024 * 1024   // 8 MB 一块

        while true {
            // 每块之间检查是否被停止，做到及时响应
            if stopFlag.isStopped { return nil }

            guard let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty else {
                break   // 读完了
            }

            pipeline.update(chunk)

            // 累加进度，并按需上报（做了节流，避免频繁刷新界面）
            let (fraction, shouldReport) = tracker.add(Int64(chunk.count))
            if shouldReport {
                DispatchQueue.main.async {
                    onProgress(fraction)
                }
            }
        }

        // 收集各算法结果，组装成字典
        let values = pipeline.finalize()
        var hashes: [HashAlgorithm: String] = [:]
        for (algorithm, value) in zip(algorithms, values) {
            hashes[algorithm] = value
        }

        return FileHashResult(
            path: url.path,
            sizeBytes: FileInfo.fileSize(url),
            version: FileInfo.version(url),
            modifiedTime: FileInfo.modifiedTime(url),
            hashes: hashes
        )
    }
}

// ============================================================================
// 下面几个是引擎内部使用的小工具类
// ============================================================================

/// 线程安全的布尔标志（用 NSLock 保护读写）
final class StopFlag {
    private let lock = NSLock()
    private var stopped = false

    func set(_ value: Bool) {
        lock.lock()
        stopped = value
        lock.unlock()
    }

    var isStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }
}

/// 线程安全的进度统计器
final class ProgressTracker {
    private let lock = NSLock()
    private let totalBytes: Int64
    private var processedBytes: Int64 = 0
    private var lastReportedFraction: Double = -1

    init(totalBytes: Int64) {
        self.totalBytes = totalBytes
    }

    /// 累加已处理的字节数，返回 (当前进度, 是否需要上报)。
    /// 只有进度相比上次上报变化超过 0.05% 时才需要上报，用于节流。
    @discardableResult
    func add(_ bytes: Int64) -> (fraction: Double, shouldReport: Bool) {
        lock.lock()
        defer { lock.unlock() }

        processedBytes += bytes
        let fraction: Double
        if totalBytes > 0 {
            fraction = min(1.0, Double(processedBytes) / Double(totalBytes))
        } else {
            fraction = 0
        }

        let shouldReport = (fraction - lastReportedFraction) >= 0.0005 || fraction >= 1.0
        if shouldReport {
            lastReportedFraction = fraction
        }
        return (fraction, shouldReport)
    }

    /// 当前整体进度（0.0 ~ 1.0）
    var fraction: Double {
        lock.lock()
        defer { lock.unlock() }
        guard totalBytes > 0 else { return 0 }
        return min(1.0, Double(processedBytes) / Double(totalBytes))
    }
}
