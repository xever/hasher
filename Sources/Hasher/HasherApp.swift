import SwiftUI

// ============================================================================
// Hasher 应用入口（SwiftUI 版）
// ----------------------------------------------------------------------------
// 使用 SwiftUI 的 App 生命周期（@main），不再需要手写 NSApplication。
// 窗口默认 650 x 550，允许调整大小但不会小于这个尺寸。
// ============================================================================

@main
struct HasherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 650, minHeight: 550)
        }
        // 设置窗口的默认大小
        .defaultSize(width: 650, height: 550)
        .commands {
            // 自定义“关于”菜单项：打开我们自己的“关于”窗口（带 GitHub 链接）。
            // 按钮文字本地化（跟随当前语言）。
            CommandGroup(replacing: .appInfo) {
                Button(L10n.tr("menu.about")) {
                    AboutWindow.show()
                }
            }

            // 移除 View 菜单（通常包含全屏切换、工具栏显示等）
            CommandGroup(replacing: .toolbar) { }
            CommandGroup(replacing: .systemServices) { }
            CommandGroup(replacing: .sidebar) { }

            // 移除 Window 菜单（最小化、缩放、窗口列表等）
            CommandGroup(replacing: .windowList) { }
            CommandGroup(replacing: .windowArrangement) { }
            CommandGroup(replacing: .windowSize) { }
        }
    }
}
