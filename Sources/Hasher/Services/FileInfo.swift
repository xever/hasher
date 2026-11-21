import Foundation

// ============================================================================
// 文件信息工具
// ----------------------------------------------------------------------------
// 负责获取文件的元信息（大小、版本、修改时间），以及把用户选择的
// 文件/文件夹展开成一个个具体的文件。
// ============================================================================

enum FileInfo {

    /// 获取文件大小（字节）。失败时返回 0。
    static func fileSize(_ url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    /// 获取文件版本。只有 .app 等 bundle 才带有版本信息（在 Info.plist 里），
    /// 普通文件返回 "—"。
    static func version(_ url: URL) -> String {
        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: infoURL) as? [String: Any] else {
            return "—"
        }
        let short = dict["CFBundleShortVersionString"] as? String ?? ""
        let build = dict["CFBundleVersion"] as? String ?? ""

        if !short.isEmpty && !build.isEmpty {
            return "\(short) (\(build))"
        }
        if !short.isEmpty { return short }
        if !build.isEmpty { return build }
        return "—"
    }

    /// 获取文件修改时间，格式 yyyy-MM-dd HH:mm:ss。失败时返回 "—"。
    static func modifiedTime(_ url: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        guard let date = attributes?[.modificationDate] as? Date else {
            return "—"
        }
        // DateFormatter 每次新建，保证多线程下安全（这里会在后台线程被调用）
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    /// 把用户选择的路径展开成“文件”列表：
    ///   - 普通文件：原样保留
    ///   - 文件夹：递归枚举其中的所有文件（忽略子文件夹本身）
    static func expandFiles(from urls: [URL]) -> [URL] {
        var result: [URL] = []
        let fm = FileManager.default

        for url in urls {
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }

            if isDirectory.boolValue {
                // 使用 enumerator 深度优先遍历文件夹
                if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: nil) {
                    for case let fileURL as URL in enumerator {
                        var dir: ObjCBool = false
                        if fm.fileExists(atPath: fileURL.path, isDirectory: &dir), !dir.boolValue {
                            result.append(fileURL)
                        }
                    }
                }
            } else {
                result.append(url)
            }
        }
        return result
    }

    /// 把字节数格式化成 “xx.xx MB (带千分位的字节数 字节)” 的形式
    static func formatSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576.0
        let mbText = String(format: "%.2f", mb)

        // NumberFormatter 负责把字节数按千分位分组（例如 1,234,567）
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        let bytesText = formatter.string(from: NSNumber(value: bytes)) ?? "\(bytes)"

        return "\(mbText) MB (\(bytesText) \(L10n.tr("unit.bytes")))"
    }
}
