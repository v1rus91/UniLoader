import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var updating = false
    @State private var updateMessage = ""

    private let browsers = ["", "chrome", "firefox", "safari", "edge", "brave", "opera", "chromium", "vivaldi"]
    private let bookmarklet = "javascript:location.href='uniloader://download?url='+encodeURIComponent(location.href)"

    var body: some View {
        @Bindable var prefs = model.prefs
        Form {
            Section("Вигляд") {
                Picker("Тема", selection: $prefs.appearance) { Text("Системна").tag("system"); Text("Темна").tag("dark"); Text("Світла").tag("light") }
                Toggle("Іконка в рядку меню", isOn: $prefs.menuBar)
                Text("Скляні панелі (Liquid Glass) працюють на macOS 26; на старіших системах — матеріали з блюром. Швидка панель: ⌘⇧D з будь-якої програми.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Буфер обміну та сповіщення") {
                Toggle("Стежити за буфером обміну", isOn: $prefs.watchClipboard)
                Toggle("Одразу ставити знайдені посилання в чергу", isOn: $prefs.clipboardAutoAdd).disabled(!prefs.watchClipboard)
                Toggle("Сповіщення про завершення", isOn: $prefs.notifications)
                Toggle("Звук по завершенні", isOn: $prefs.sound)
                Text("Коли ви копіюєте посилання на підтримуваний сервіс, застосунок показує тост із кнопкою «Завантажити». Лічильник активних завантажень показується на іконці в Dock.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Завантаження") {
                HStack {
                    TextField("Тека за замовчуванням", text: $prefs.downloadDir)
                    Button("Обрати…") { if let d = SystemActions.chooseFolder(initial: prefs.downloadDir) { prefs.downloadDir = d } }
                }
                Stepper(String(format: L("Паралельних завантажень: %d"), prefs.maxWorkers), value: $prefs.maxWorkers, in: 1...4)
                TextField("Шаблон імені файлу", text: $prefs.template)
                Text("Поля yt-dlp: %(title)s, %(id)s, %(uploader)s, %(upload_date)s, %(ext)s тощо.").font(.caption).foregroundStyle(.secondary)
                Toggle("Вбудовувати метадані (назва, автор)", isOn: $prefs.embedMetadata)
                Toggle("Автоматично оновлювати yt-dlp раз на тиждень", isOn: $prefs.autoUpdate)
            }
            Section("Мережа та просунуті опції") {
                TextField("Проксі (http://host:port або socks5://…)", text: $prefs.proxy)
                TextField("Ліміт швидкості (наприклад 2M)", text: $prefs.rateLimit)
                TextField("Додаткові аргументи yt-dlp", text: $prefs.extraArgs)
                Toggle("Вирізати спонсорські вставки (SponsorBlock)", isOn: $prefs.sponsorBlock)
                Toggle("Ділити на розділи", isOn: $prefs.splitChapters)
            }
            Section("Доступ і приватний контент") {
                Picker("Cookies із браузера", selection: $prefs.cookiesBrowser) {
                    ForEach(browsers, id: \.self) { Text(verbatim: $0.isEmpty ? L("Вимкнено") : $0).tag($0) }
                }
                HStack {
                    TextField("Файл cookies.txt (має пріоритет над браузером)", text: $prefs.cookiesFile)
                    Button("Обрати…") { if let f = SystemActions.chooseFile() { prefs.cookiesFile = f } }
                    if !prefs.cookiesFile.isEmpty { Button("Прибрати") { prefs.cookiesFile = "" } }
                }
                Text("Потрібно для Instagram, приватних відео, контенту 18+, Patreon тощо. Файл cookies.txt (розширення «Get cookies.txt LOCALLY») не викликає запит пароля Keychain.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Браузер") {
                Text("Закладка «Завантажити в UniLoader»: створіть закладку з цією адресою й натискайте її на сторінці з відео.").font(.callout)
                HStack {
                    Text(verbatim: bookmarklet).font(.system(.caption, design: .monospaced)).textSelection(.enabled).lineLimit(2).truncationMode(.middle)
                    Spacer()
                    Button("Скопіювати") { SystemActions.copy(bookmarklet); model.manager.showToast(L("Скопійовано"), .info, seconds: 1.2) }
                }
                Text("Також працює URL-схема uniloader://download?url=… для інших програм і скриптів.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Інструменти") {
                LabeledContent("yt-dlp") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: ToolInfo.shared.ytdlpVersion)
                        Text(verbatim: Tools.ytdlp() ?? L("не знайдено")).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                }
                HStack {
                    TextField("Шлях до ffmpeg (порожньо — вбудований або з PATH)", text: $prefs.ffmpegPath).onSubmit { ToolInfo.shared.refresh() }
                    Button("Перевірити") { ToolInfo.shared.refresh() }
                }
                let ff = Tools.ffmpeg(configured: prefs.ffmpegPath)
                Label(ff.map { "\($0)  ·  \(ToolInfo.shared.ffmpegVersion)" } ?? L("ffmpeg не знайдено. Вкажіть шлях або встановіть: brew install ffmpeg"),
                      systemImage: ff != nil ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(ff != nil ? .green : .red).font(.callout).lineLimit(2).truncationMode(.middle)
                HStack {
                    Button(updating ? "Оновлення…" : "Оновити yt-dlp") { updateYtdlp() }.disabled(updating)
                    if !updateMessage.isEmpty { Text(verbatim: updateMessage).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                }
            }
            Section {
                Button { model.showShortcuts = true } label: { Label("Клавіатурні шорткати  ⌘/", systemImage: "keyboard") }
                Text("Проєкт створено виключно з ознайомлювальною метою. Поважайте авторські права та умови використання сервісів. Музичні сервіси (Spotify, Apple Music, Shazam, Deezer…) не завантажуються напряму: за їхніми посиланнями визначається трек, який потім шукається на YouTube.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func updateYtdlp() {
        updating = true; updateMessage = ""
        Task.detached {
            let (ok, msg, _) = Tools.updateYtdlp()
            await MainActor.run { updating = false; updateMessage = (ok ? "✓ " : "✗ ") + msg; ToolInfo.shared.refresh() }
        }
    }
}
