import Foundation
import Combine

// ============================================================================
// 本地化（多语言）管理
// ----------------------------------------------------------------------------
// 设计：
//   - AppLanguage：支持的语言（中文 / 英文）
//   - LanguageManager：单例，负责“当前语言”状态，并直接读取、解析 .strings 文件
//   - L10n.tr(key)：简写入口，供模型层 / 服务层方便调用
//
// 为什么不直接用系统的 NSLocalizedString？
//   系统 API 只能跟随系统语言，无法在应用内“运行时切换”。
//   为了支持界面右上角的“切换语言”按钮，这里改为自己读取 .lproj 里的
//   Localizable.strings 并解析成字典，这样既能启动时跟随系统语言，
//   也能在运行中一键切换、即时刷新。
//
// .strings 文件本质上是“旧式 plist 格式”，可以用 PropertyListSerialization
// 直接解析成 [String: String] 字典，非常方便。
// ============================================================================

/// 支持的语言
enum AppLanguage: String, CaseIterable {
    case chinese = "zh-Hans"
    case english = "en"

    /// 用于界面按钮上显示的语言名（语言名永远用该语言本身书写）
    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }

    /// 对应的语言文件夹名，例如 "zh-Hans.lproj"
    var lprojName: String {
        return "\(rawValue).lproj"
    }
}

/// 语言管理器：单例 + 可观察，切换语言时界面会自动刷新
final class LanguageManager: ObservableObject {

    /// 全局唯一实例
    static let shared = LanguageManager()

    /// 当前语言（外部只读，通过 toggle() / setLanguage() 修改）
    @Published private(set) var language: AppLanguage

    /// 每种语言对应的翻译表（key -> 文字）
    private var tables: [AppLanguage: [String: String]] = [:]

    /// 用户上次选择的语言保存在 UserDefaults 里的键
    private static let storageKey = "Hasher.AppLanguage"

    private init() {
        self.language = Self.loadInitialLanguage()
        self.loadAllTables()
    }

    /// 取当前语言下某个 key 的文字；找不到时返回 key 本身，方便排查遗漏
    func tr(_ key: String) -> String {
        return tables[language]?[key] ?? key
    }

    /// 在中文 / 英文之间切换
    func toggle() {
        setLanguage(language == .chinese ? .english : .chinese)
    }

    /// 切换到指定语言
    func setLanguage(_ newLanguage: AppLanguage) {
        guard newLanguage != language else { return }
        language = newLanguage
        UserDefaults.standard.set(newLanguage.rawValue, forKey: Self.storageKey)
    }

    /// 决定启动时用哪种语言：优先用户上次的选择，否则跟随系统语言
    private static func loadInitialLanguage() -> AppLanguage {
        if let saved = UserDefaults.standard.string(forKey: storageKey),
           let lang = AppLanguage(rawValue: saved) {
            return lang
        }
        // 系统首选语言以 "zh" 开头（zh / zh-Hans / zh-Hant 等）就显示中文，否则英文
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("zh") ? .chinese : .english
    }

    /// 加载所有语言的翻译表
    private func loadAllTables() {
        for lang in AppLanguage.allCases {
            tables[lang] = loadTable(for: lang)
        }
    }

    /// 读取并解析某个语言的 Localizable.strings
    private func loadTable(for lang: AppLanguage) -> [String: String] {
        guard let path = Bundle.module.path(forResource: "Localizable",
                                            ofType: "strings",
                                            inDirectory: lang.lprojName),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let dict = try? PropertyListSerialization.propertyList(from: data,
                                                                      options: [],
                                                                      format: nil) as? [String: String] else {
            return [:]
        }
        return dict
    }
}

/// 本地化简写入口（供模型层 / 服务层使用）
enum L10n {
    static func tr(_ key: String) -> String {
        return LanguageManager.shared.tr(key)
    }
}
