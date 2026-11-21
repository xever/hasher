import Foundation

// ============================================================================
// 哈希算法枚举
// ----------------------------------------------------------------------------
// 把所有支持的算法集中在一个枚举里，界面和引擎都围绕它展开，
// 后续要新增算法时只需：加一个 case + 在 HashPipeline 里补一个分支。
// ============================================================================

/// 支持的哈希算法
enum HashAlgorithm: String, CaseIterable {
    case md5    = "MD5"
    case sha1   = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
    case crc32  = "CRC32"

    /// 显示名称（用于第二行复选框的文字）
    var displayName: String {
        switch self {
        case .md5:    return L10n.tr("algorithm.md5")
        case .sha1:   return L10n.tr("algorithm.sha1")
        case .sha256: return L10n.tr("algorithm.sha256")
        case .sha512: return L10n.tr("algorithm.sha512")
        case .crc32:  return L10n.tr("algorithm.crc32")
        }
    }

    /// 是否默认勾选：需求规定默认勾选 MD5 和 SHA256
    var isDefaultSelected: Bool {
        return self == .md5 || self == .sha256
    }
}
