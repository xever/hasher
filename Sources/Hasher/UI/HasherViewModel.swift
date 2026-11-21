import SwiftUI
import AppKit
import UniformTypeIdentifiers

// ============================================================================
// 视图模型（ViewModel）
// ----------------------------------------------------------------------------
// 界面显示的所有“状态”都集中在这里（@Published），界面只负责展示和触发操作，
// 业务逻辑（计算哈希、读取文件等）仍然调用底层的 HashEngine 服务层。
//
// 分层：View（ContentView） -> ViewModel（本类） -> Service（HashEngine）。
// ============================================================================

final class HasherViewModel: ObservableObject {

    // MARK: - 算法与信息选项（对应第二、三行复选框）

    /// 勾选的算法集合（默认 MD5 和 SHA256）
    @Published var selectedAlgorithms: Set<HashAlgorithm> = [.md5, .sha256]

    /// 是否显示文件路径
    @Published var showPath = true
    /// 是否显示文件大小
    @Published var showSize = true
    /// 是否显示文件版本
    @Published var showVersion = true
    /// 是否显示修改时间
    @Published var showModifiedTime = true
    /// 结果是否大写
    @Published var uppercaseResult = true

    // MARK: - 结果与进度

    /// 计算出的结果（结构化保存，界面按需排版）
    @Published var results: [FileHashResult] = []
    /// 结果区当前是否有真实结果（用于区分占位提示与结果）
    @Published var hasResults = false
    /// 计算进度（0.0 ~ 1.0）
    @Published var progress: Double = 0

    // MARK: - 比较/检测

    /// 比较输入框的文字
    @Published var compareText = ""
    /// 检测结果状态：决定输入框背景颜色
    @Published var compareState: CompareState = .none

    /// 检测的三种状态
    enum CompareState {
        case none          // 未检测（默认背景）
        case matched       // 命中 -> 浅蓝色
        case notMatched    // 未命中 -> 粉红色
    }

    // MARK: - 结果行结构

    /// 结果里的一行：text 为文字，isInfo 表示是否为“信息行”（信息行加粗显示）
    struct ResultLine {
        let text: String
        let isInfo: Bool
    }

    // MARK: - 私有

    private let engine = HashEngine()
    /// 任务标识：每次开始新计算或清空时自增，用于忽略过期任务的回调
    private var taskID = 0

    // MARK: - 按钮操作

    /// 浏览：打开文件选择面板（可多选、可选文件夹），选中后开始计算
    func browse() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.message = L10n.tr("browse.message")
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            self?.startComputing(urls: panel.urls)
        }
    }

    /// 清除：清空结果区，恢复到占位提示
    func clear() {
        taskID += 1   // 让仍在进行的任务结果失效
        hasResults = false
        results = []
        progress = 0
    }

    /// 复制：把结果复制到剪贴板
    func copy() {
        guard hasResults else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(plainText, forType: .string)
    }

    /// 保存：把结果保存成 UTF-8 文本文件
    func save() {
        guard hasResults else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "hasher-results.txt"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            guard let self = self else { return }
            try? self.plainText.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// 停止：停止正在进行的计算
    func stop() {
        engine.stop()
    }

    /// 粘贴：把剪贴板文字粘贴到比较输入框
    func paste() {
        if let text = NSPasteboard.general.string(forType: .string) {
            compareText = text
        }
    }

    /// 检测：在结果里搜索输入框内容，命中变浅蓝、未命中变粉红
    func detect() {
        let keyword = compareText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            compareState = .none
            return
        }
        let found = plainText.range(of: keyword, options: .caseInsensitive) != nil
        compareState = found ? .matched : .notMatched
    }

    // MARK: - 计算流程

    /// 开始计算：展开文件夹、校验算法、启动引擎
    func startComputing(urls: [URL]) {
        let files = FileInfo.expandFiles(from: urls)
        guard !files.isEmpty else { return }

        let algorithms = orderedSelectedAlgorithms()
        guard !algorithms.isEmpty else {
            showAlert(L10n.tr("alert.selectAlgorithm"))
            return
        }

        taskID += 1
        let id = taskID

        hasResults = false
        results = []
        progress = 0

        // 引擎的回调都会在主线程执行（引擎内部用 DispatchQueue.main.async 调度）
        engine.compute(
            files: files,
            algorithms: algorithms,
            onProgress: { [weak self] fraction in
                guard let self = self, id == self.taskID else { return }
                self.progress = fraction
            },
            onComplete: { [weak self] results in
                guard let self = self, id == self.taskID else { return }
                self.showResults(results)
            }
        )
    }

    /// 按固定顺序（MD5/SHA1/...）返回当前勾选的算法
    private func orderedSelectedAlgorithms() -> [HashAlgorithm] {
        return HashAlgorithm.allCases.filter { selectedAlgorithms.contains($0) }
    }

    /// 展示计算结果
    private func showResults(_ newResults: [FileHashResult]) {
        hasResults = true
        results = newResults
        progress = 1.0
    }

    // MARK: - 结果格式化

    /// 用于复制 / 保存 / 搜索的纯文本：
    /// 每个信息、每个算法各占一行，不同文件之间空一行
    var plainText: String {
        return results.map { result in
            lines(for: result).map(\.text).joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    /// 把单个文件拆成多行：先信息行（加粗），再算法结果行（常规）
    func lines(for result: FileHashResult) -> [ResultLine] {
        var lines: [ResultLine] = []
        if showPath {
            lines.append(ResultLine(text: result.path, isInfo: true))
        }
        if showSize {
            lines.append(ResultLine(text: FileInfo.formatSize(result.sizeBytes), isInfo: true))
        }
        if showVersion {
            lines.append(ResultLine(text: "\(L10n.tr("label.version")): \(result.version)", isInfo: true))
        }
        if showModifiedTime {
            lines.append(ResultLine(text: "\(L10n.tr("label.modifiedTime")): \(result.modifiedTime)", isInfo: true))
        }
        for algorithm in orderedSelectedAlgorithms() {
            if let value = result.hashes[algorithm] {
                let text = uppercaseResult ? value.uppercased() : value
                lines.append(ResultLine(text: "\(algorithm.rawValue): \(text)", isInfo: true))
            }
        }
        return lines
    }

    // MARK: - 弹窗

    private func showAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = L10n.tr("alert.title")
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
