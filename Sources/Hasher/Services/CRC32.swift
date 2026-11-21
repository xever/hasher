import Foundation

// ============================================================================
// CRC32 哈希器（手动实现）
// ----------------------------------------------------------------------------
// CryptoKit 没有提供 CRC32，所以这里自己实现一个。
// 使用 IEEE 802.3（也是 zlib 使用的）标准：
//   - 多项式 0xEDB88320（反射形式）
//   - 初始值 0xFFFFFFFF，结果再与 0xFFFFFFFF 异或
//
// 为了性能，预先计算一张 256 项的查找表，这样每个字节只需要一次查表运算，
// 而不是循环 8 次移位。大文件下速度会快很多。
// ============================================================================

final class CRC32Hasher: Hasher {

    /// 当前校验值（初始为全 1）
    private var crc: UInt32 = 0xFFFF_FFFF

    /// 预先计算好的查找表
    private static let table: [UInt32] = {
        var t = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var c = UInt32(i)
            for _ in 0..<8 {
                // 如果最低位是 1，就右移一位并与多项式异或；否则直接右移
                c = (c & 1) != 0 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1)
            }
            t[i] = c
        }
        return t
    }()

    func update(_ chunk: Data) {
        var c = crc
        // withUnsafeBytes 可以高效地遍历原始字节，比 for byte in chunk 快得多
        chunk.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            for byte in buffer {
                let index = Int((c ^ UInt32(byte)) & 0xFF)
                c = Self.table[index] ^ (c >> 8)
            }
        }
        crc = c
    }

    func finalHex() -> String {
        let value = crc ^ 0xFFFF_FFFF
        // CRC32 习惯上用 8 位十六进制展示
        return String(format: "%08x", value)
    }
}
