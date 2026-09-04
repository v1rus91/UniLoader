import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(selection: $model.page) {
                Section("Завантаження") { row(.download); row(.queue); row(.history) }
                Section("Довідка") { row(.services); row(.settings) }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
            .safeAreaInset(edge: .bottom) { sidebarFooter }
        } detail: {
            detail.navigationTitle(model.page?.title ?? "")
        }
        .glassWindowBackground()
        .overlay(alignment: .bottom) {
            if let t = model.manager.toast {
                ToastView(toast: t).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.2), value: model.manager.toast)
        .sheet(isPresented: $model.showShortcuts) { ShortcutsSheet() }
        .sheet(isPresented: $model.showOnboarding) { OnboardingSheet() }
        .preferredColorScheme(model.prefs.appearance == "dark" ? .dark : model.prefs.appearance == "light" ? .light : nil)
        .frame(minWidth: 940, minHeight: 600)
        .onOpenURL { model.handleOpenURL($0) }
        .onReceive(NotificationCenter.default.publisher(for: .openQuickPanel)) { _ in
            openWindow(id: "quick")
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @ViewBuilder private var detail: some View {
        switch model.page ?? .download {
        case .download: DownloadView()
        case .queue: QueueView()
        case .history: HistoryView()
        case .services: ServicesView()
        case .settings: SettingsView()
        }
    }

    private func row(_ p: Page) -> some View {
        Label(p.title, systemImage: p.symbol).badge(p == .queue ? model.manager.activeCount : 0).tag(p)
    }

    private var sidebarFooter: some View {
        let ff = Tools.ffmpeg(configured: model.prefs.ffmpegPath) != nil
        return VStack(alignment: .leading, spacing: 3) {
            Label(ff ? "ffmpeg готовий" : "ffmpeg не знайдено", systemImage: ff ? "circle.fill" : "circle").foregroundStyle(ff ? .green : .red)
            Text(verbatim: "yt-dlp \(ToolInfo.shared.ytdlpVersion)").foregroundStyle(.secondary)
            Text("v2.1 · лише для ознайомлення").foregroundStyle(.tertiary)
        }
        .font(.caption).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 12)
    }
}

@Observable
final class ToolInfo {
    static let shared = ToolInfo()
    var ytdlpVersion = "…"
    var ffmpegVersion = ""
    init() { refresh() }
    func refresh() {
        Task.detached { [weak self] in
            let y = Tools.version(Tools.ytdlp())
            let f = Tools.version(Tools.ffmpeg(configured: UserDefaults.standard.string(forKey: "ffmpegPath") ?? ""), args: ["-version"])
            await MainActor.run { self?.ytdlpVersion = y.isEmpty ? "?" : y; self?.ffmpegVersion = f }
        }
    }
}

/// Швидка панель (⌘⇧D з будь-якої програми): одне поле, вставити, завантажити.
struct QuickPanelView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var prefs = model.prefs
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(.tint).font(.title2)
                TextField("Посилання на відео, трек або плейлист", text: $text)
                    .textFieldStyle(.plain).font(.title3).focused($focused)
                    .onSubmit { go() }
            }
            HStack {
                Picker("", selection: $prefs.mode) { ForEach(Mode.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented).labelsHidden().frame(width: 160)
                Spacer()
                Button("Вставити") { text = SystemActions.clipboardString() ?? "" }.glassButton()
                Button { go() } label: { HStack { Text("Завантажити"); Kbd(keys: "↩") } }.glassButton(prominent: true).disabled(extractURLs(text).isEmpty)
            }
            if model.manager.activeCount > 0 {
                Text(verbatim: String(format: L("Активних завантажень: %d"), model.manager.activeCount)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(18).frame(width: 520)
        .glassWindowBackground()
        .onAppear { focused = true; if text.isEmpty, let s = SystemActions.clipboardString(), !extractURLs(s).isEmpty { text = s } }
        .onExitCommand { dismiss() }
    }

    private func go() {
        let urls = extractURLs(text)
        guard !urls.isEmpty else { return }
        model.addBatch(urls)
        text = ""
        dismiss()
    }
}
