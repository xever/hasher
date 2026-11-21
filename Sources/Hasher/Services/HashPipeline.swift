import Foundation

// ============================================================================
// 哈希流水线
// ----------------------------------------------------------------------------
// “流水线”的核心思想：对同一块数据，同时更新所有被勾选的算法。
// 这样磁盘只需要读取一次，就能一次性算出 MD5、SHA1、SHA256…… 全部结果，
// 大幅减少磁盘 IO，满足“允许同时计算多个 hash，减少磁盘 io”的需求。
// ============================================================================

final class HashPipeline {

    /// 内部维护的一组哈希器，顺序与传入的算法顺序一致
    private let hashers: [Hasher]

    /// 根据用户选择的算法创建对应的哈希器
    init(algorithms: [HashAlgorithm]) {
        self.hashers = algorithms.map { algorithm -> Hasher in
            switch algorithm {
            case .md5:    return MD5Hasher()
            case .sha1:   return SHA1Hasher()
            case .sha256: return SHA256Hasher()
            case .sha512: return SHA512Hasher()
            case .crc32:  return CRC32Hasher()
            }
        }
    }

    /// 把一块数据同时送入所有哈希器
    func update(_ chunk: Data) {
        for hasher in hashers {
            hasher.update(chunk)
        }
    }

    /// 结束计算，返回与构造时算法顺序一致的十六进制结果（小写）
    func finalize() -> [String] {
        return hashers.map { $0.finalHex() }
    }
}
