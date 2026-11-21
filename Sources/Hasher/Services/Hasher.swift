import Foundation
import CryptoKit

// ============================================================================
// 哈希器接口与实现（MD5 / SHA1 / SHA256 / SHA512）
// ----------------------------------------------------------------------------
// MD5、SHA 系列使用苹果自带的 CryptoKit 框架实现。
// CryptoKit 属于系统框架，不算“外部组件”，因此符合“减少外部依赖”的要求。
//
// 这里统一抽象成一个 Hasher 协议，让“流水线”可以同时驱动多个算法，
// 从而做到“读一次磁盘、算多个哈希”。
// ============================================================================

/// 所有哈希器都需要实现的接口
protocol Hasher {
    /// 把一块数据送入哈希器（增量计算，可以反复调用）
    func update(_ chunk: Data)
    /// 结束计算，返回十六进制字符串（小写）
    func finalHex() -> String
}

/// 把 CryptoKit 的摘要（Digest）转成小写十六进制字符串的公共辅助函数
func hexString<S: Sequence>(_ digest: S) -> String where S.Element == UInt8 {
    return digest.map { String(format: "%02x", $0) }.joined()
}

/// MD5 哈希器
final class MD5Hasher: Hasher {
    // Insecure.MD5 提供“增量”计算能力，适合分块读取大文件
    private var hasher = Insecure.MD5()

    func update(_ chunk: Data) {
        hasher.update(data: chunk)
    }

    func finalHex() -> String {
        return hexString(hasher.finalize())
    }
}

/// SHA1 哈希器
final class SHA1Hasher: Hasher {
    private var hasher = Insecure.SHA1()

    func update(_ chunk: Data) {
        hasher.update(data: chunk)
    }

    func finalHex() -> String {
        return hexString(hasher.finalize())
    }
}

/// SHA256 哈希器
final class SHA256Hasher: Hasher {
    private var hasher = SHA256()

    func update(_ chunk: Data) {
        hasher.update(data: chunk)
    }

    func finalHex() -> String {
        return hexString(hasher.finalize())
    }
}

/// SHA512 哈希器
final class SHA512Hasher: Hasher {
    private var hasher = SHA512()

    func update(_ chunk: Data) {
        hasher.update(data: chunk)
    }

    func finalHex() -> String {
        return hexString(hasher.finalize())
    }
}
