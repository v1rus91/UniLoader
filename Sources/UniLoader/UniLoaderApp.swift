import SwiftUI

struct UniLoaderApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView().environment(model)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1120, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Нове завантаження") { model.newDownload() }.keyboardShortcut("n")
                Button("Імпортувати посилання з файлу…") { model.importFromFile() }.keyboardShortcut("o")
                Button("Вставити посилання й аналізувати") { model.pasteAndAnalyze() }.keyboardShortcut("v", modifiers: [.command, .shift])
                Button("Аналізувати") { model.analyze() }.keyboardShortcut("r")
                Button("Завантажити") { model.download() }.keyboardShortcut(.return, modifiers: .command)
                Divider()
                Button("Поле посилання") { model.focusURL() }.keyboardShortcut("l")
                Button("Швидка панель") { NotificationCenter.default.post(name: .openQuickPanel, object: nil) }.keyboardShortcut("d", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .appSettings) {
                Button("Налаштування…") { model.page = .settings }.keyboardShortcut(",")
            }
            CommandMenu("Розділи") {
                ForEach(Array(Page.allCases.enumerated()), id: \.element) { i, p in
                    Button(p.title) { model.page = p }.keyboardShortcut(KeyEquivalent(Character(String(i + 1))))
                }
            }
            CommandGroup(replacing: .help) {
                Button("Клавіатурні шорткати") { model.showShortcuts = true }.keyboardShortcut("/")
            }
        }

        Window("Швидке завантаження", id: "quick") {
            QuickPanelView().environment(model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        MenuBarExtra(isInserted: Binding(get: { model.prefs.menuBar }, set: { model.prefs.menuBar = $0 })) {
            Button("Швидка панель  ⌘⇧D") { NotificationCenter.default.post(name: .openQuickPanel, object: nil) }
            Button("Вставити посилання й завантажити") { model.pasteAndAnalyze() }
            Divider()
            Text(verbatim: model.manager.activeCount > 0 ? String(format: L("Активних завантажень: %d"), model.manager.activeCount) : L("Черга порожня"))
            Button("Показати чергу") { model.page = .queue; NSApp.activate(ignoringOtherApps: true) }
            Divider()
            Button("Показати UniLoader") { NSApp.activate(ignoringOtherApps: true) }
            Button("Вийти") { NSApp.terminate(nil) }.keyboardShortcut("q")
        } label: {
            Image(systemName: model.manager.activeCount > 0 ? "arrow.down.circle.fill" : "arrow.down.circle")
        }
    }
}
