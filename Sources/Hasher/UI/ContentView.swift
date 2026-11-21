import SwiftUI
import UniformTypeIdentifiers

// ============================================================================
// 主界面（SwiftUI 版）
// ----------------------------------------------------------------------------
// 上下两区：上面是 5 行操作控件，下面是结果区。
//   第一行：浏览 / 清除 / 复制 / 保存 / 停止     （最右边：切换语言按钮）
//   第二行：算法多选框（MD5、SHA1、SHA256、SHA512、CRC32）
//   第三行：信息多选框（文件路径、文件大小、文件版本、修改时间、结果大写）
//   第四行：进度 + 蓝色进度条
//   第五行：比较 + 输入框 + 粘贴 + 检测
//   结果区：显示结果（信息加粗、每个信息单独一行、文件之间空一行），支持拖拽
// ============================================================================

struct ContentView: View {

    /// 视图模型：持有全部界面状态
    @StateObject private var viewModel = HasherViewModel()

    /// 语言管理器：切换语言时让整个界面刷新
    @ObservedObject private var languageManager = LanguageManager.shared

    /// 是否正在被拖拽悬停（用于高亮结果区边框）
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            buttonRow
            algorithmRow
            infoRow
            progressRow
            compareRow
            resultsArea
        }
        .padding(12)
    }

    // MARK: - 第一行：操作按钮（最右边是切换语言按钮）

    private var buttonRow: some View {
        HStack(spacing: 8) {
            Button(L10n.tr("button.browse")) { viewModel.browse() }
            .controlSize(.large) // 整体加大一号
            .buttonStyle(.borderedProminent) // 填充背景色
            .tint(.blue) // 指定为蓝色
            
            Button(L10n.tr("button.clear")) { viewModel.clear() }
            Button(L10n.tr("button.copy")) { viewModel.copy() }
            Button(L10n.tr("button.save")) { viewModel.save() }
            Button(L10n.tr("button.stop")) { viewModel.stop() }
            Spacer()
            languageToggleButton
        }// 3. 统一控制这一行所有按钮的尺寸，避免重复写 .controlSize(.large)
        .controlSize(.large).frame(minWidth: 100) 
    }

    /// 切换语言按钮：显示“目标语言”，点击即切换
    private var languageToggleButton: some View {
        let targetName = languageManager.language == .chinese
            ? AppLanguage.english.displayName
            : AppLanguage.chinese.displayName
        return Button {
            languageManager.toggle()
        } label: {
            Label(targetName, systemImage: "globe")
        }
        .help(L10n.tr("button.switchLanguage"))
    }

    // MARK: - 第二行：算法复选框

    private var algorithmRow: some View {
        HStack(spacing: 14) {
            Text(L10n.tr("label.algorithm"))
            ForEach(HashAlgorithm.allCases, id: \.self) { algorithm in
                Toggle(algorithm.displayName, isOn: algorithmBinding(algorithm))
                    .toggleStyle(.checkbox)
            }
        }
    }

    // MARK: - 第三行：信息复选框

    private var infoRow: some View {
        HStack(spacing: 14) {
            Text(L10n.tr("label.info"))
            Toggle(L10n.tr("checkbox.filePath"), isOn: $viewModel.showPath)
                .toggleStyle(.checkbox)
            Toggle(L10n.tr("checkbox.fileSize"), isOn: $viewModel.showSize)
                .toggleStyle(.checkbox)
            Toggle(L10n.tr("checkbox.fileVersion"), isOn: $viewModel.showVersion)
                .toggleStyle(.checkbox)
            Toggle(L10n.tr("checkbox.modifiedTime"), isOn: $viewModel.showModifiedTime)
                .toggleStyle(.checkbox)
            Toggle(L10n.tr("checkbox.uppercase"), isOn: $viewModel.uppercaseResult)
                .toggleStyle(.checkbox)
        }
    }

    // MARK: - 第四行：进度条

    private var progressRow: some View {
        HStack(spacing: 8) {
            Text(L10n.tr("label.progress"))
            // linear 样式 + 蓝色 tint
            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)
                .tint(.blue)
        }
    }

    // MARK: - 第五行：比较 / 检测

    private var compareRow: some View {
        HStack(spacing: 8) {
            Text(L10n.tr("label.compare"))
            // 用 .plain 样式 + 自定义背景，才能让背景色随“检测”结果变化
            TextField(L10n.tr("compare.placeholder"), text: $viewModel.compareText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(compareColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
            Button {
                viewModel.paste()
            } label: {
                Image(systemName: "doc.on.clipboard")
            }
            .help(L10n.tr("button.paste"))
            Button(L10n.tr("button.detect")) {
                viewModel.detect()
            }
        }
    }

    // MARK: - 结果区

    private var resultsArea: some View {
        Group {
            if viewModel.hasResults {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(viewModel.results.enumerated()), id: \.offset) { _, result in
                            resultBlock(result)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ScrollView {
                    Text(L10n.tr("result.placeholder"))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isDropTargeted ? Color.blue : Color(nsColor: .separatorColor),
                        lineWidth: isDropTargeted ? 2 : 1)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    /// 一个文件的结果块：信息行加粗、算法行常规，各自单独一行
    private func resultBlock(_ result: FileHashResult) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(viewModel.lines(for: result).enumerated()), id: \.offset) { _, line in
                Text(line.text)
                    .font(line.isInfo
                          ? Font.system(.body, design: .monospaced).bold()
                          : Font.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - 辅助

    /// 比较输入框的背景色：按检测结果变化
    private var compareColor: Color {
        switch viewModel.compareState {
        case .none:       return Color(nsColor: .textBackgroundColor)
        case .matched:    return Color(red: 0.678, green: 0.847, blue: 0.902)   // 浅蓝
        case .notMatched: return Color(red: 1.000, green: 0.710, blue: 0.760)   // 粉红
        }
    }

    /// 为“算法集合”生成某个算法的勾选绑定（因为 SwiftUI 的 Toggle 需要 Bool）
    private func algorithmBinding(_ algorithm: HashAlgorithm) -> Binding<Bool> {
        Binding(
            get: { viewModel.selectedAlgorithms.contains(algorithm) },
            set: { checked in
                if checked {
                    viewModel.selectedAlgorithms.insert(algorithm)
                } else {
                    viewModel.selectedAlgorithms.remove(algorithm)
                }
            }
        )
    }

    /// 处理拖入的文件：从 NSItemProvider 中读出文件 URL，然后开始计算
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        let lock = NSLock()   // 多个 provider 可能并发回调，保护 urls 数组
        var urls: [URL] = []

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadObject(ofClass: NSURL.self) { item, _ in
                defer { group.leave() }
                if let nsurl = item as? NSURL {
                    lock.lock()
                    urls.append(nsurl as URL)
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            viewModel.startComputing(urls: urls)
        }
        return true
    }
}
