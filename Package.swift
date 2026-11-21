// swift-tools-version:6.0
//
// Hasher —— macOS 哈希计算小工具
// 本文件是 Swift Package Manager（SPM）的清单文件，用于声明：
//   - 支持的最低系统版本（macOS 15，可运行在 macOS 15 ~ 27）
//   - 生成一个名为 Hasher 的可执行程序
//   - 需要打包的本地化资源（语言文件）
//
import PackageDescription

let package = Package(
    name: "Hasher",
    // 默认语言：当系统语言不在支持列表时，回退到英文
    defaultLocalization: "en",
    platforms: [
        // 最低支持 macOS 15，向上兼容到 macOS 27
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Hasher", targets: ["Hasher"])
    ],
    targets: [
        .executableTarget(
            name: "Hasher",
            // 本地化资源放在 Sources/Hasher/Resources 目录下
            // .process 会自动识别 en.lproj / zh-Hans.lproj 等语言文件夹
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                // 使用 Swift 5 语言模式：避免严格并发检查带来的复杂报错，
                // 对刚学习 Swift 的新手更友好（并发我们用手动方式处理）
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
