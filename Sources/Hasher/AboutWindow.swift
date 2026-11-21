//
//  AboutWindow.swift
//
//  “关于”窗口：显示应用图标、名称、可点击的 GitHub 链接和版本号。
//

import SwiftUI
import AppKit

/// 负责显示“关于”窗口。
/// 用 AppKit 的 NSWindow 承载 SwiftUI 视图，方便从菜单命令里直接调用。
enum AboutWindow {

    /// 保存窗口实例，避免重复创建（关闭后再次打开可以复用）。
    private static var window: NSWindow?

    /// 显示“关于”窗口；如果已经存在则直接置于最前。
    static func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // 用 SwiftUI 视图作为窗口内容。
        let hosting = NSHostingView(rootView: AboutView())

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = L10n.tr("menu.about")
        win.contentView = hosting
        win.isReleasedWhenClosed = false   // 关闭时不销毁，方便下次直接复用
        win.center()
        window = win

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// “关于”页面内容。
struct AboutView: View {

    @State private var isHovering = false
    /// 从 Info.plist 读取版本号，例如 “版本 1.0.0 (1)”。
    private var versionText: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(L10n.tr("about.version")) \(short) (\(build))"
    }

    /// 加载打包进 App 的 GitHub 图标。
    private var githubLogo: NSImage? {
        // 图标放在 SPM 资源包里，用 Bundle.module 读取
        guard let url = Bundle.module.url(forResource: "github", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        VStack(spacing: 10) {
            // 应用图标。
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 72, height: 72)
            }

            // 应用名称。
            Text(L10n.tr("app.name"))
                .font(.title2.weight(.semibold))

            // 版本号上面的一行：GitHub 图标 + 可点击的链接。
            Link(destination: URL(string: "https://github.com/xever/")!) {
                HStack(spacing: 6) {
                    if let logo = githubLogo {
                        Image(nsImage: logo)
                            .renderingMode(.template)   // 模板渲染，颜色跟随文字，自动适配深浅色
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 16, height: 16)
                    }
                    Text("xever @GitHub")
                        .font(.callout)
                        .cornerRadius(8)
                        // 模拟 lift 效果的缩放和阴影
                        .scaleEffect(isHovering ? 1.05 : 1.0)
                        .shadow(color: isHovering ? .black.opacity(0.2) : .clear, radius: 5, x: 0, y: 2)
                }
                .foregroundColor(.accentColor)
            }
            .onHover { hovering in
                        // 加上动画让过渡更自然
                        withAnimation(.easeOut(duration: 0.2)) {
                            isHovering = hovering
                        }
                    }
//            .help("在浏览器中打开 \n https://github.com/xever")

            // 版本号。
            Text(versionText)
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .frame(width: 300, height: 200)
    }
}
