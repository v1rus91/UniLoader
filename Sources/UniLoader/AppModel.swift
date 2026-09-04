import SwiftUI
import Observation

extension Notification.Name {
    static let openQuickPanel = Notification.Name("uniloader.openQuickPanel")
}

/// Стан інтерфейсу та дії, доступні з меню й шорткатів.
@MainActor
@Observable
final class AppModel {
    var page: Page? = .download
    var url: String = ""
    var info: MediaInfo?
    var analyzing = false
    var analyzeError: String?
    var statusText = ""
    var showShortcuts = false
    var showOnboarding = false
    var showAdvanced = false
    var focusURLTick = 0
    var dropTargeted = false
    var selectedFormat: String? = nil            // nil = авто за якістю
    var selectedEntries: Set<String> = []        // вибрані елементи плейлиста / треки
    private var analyzeSeq = 0
    private var clipboardTimer: Timer?
    private var lastClipboardChange = NSPasteboard.general.changeCount
    private var lastOfferedURL = ""

    let prefs: Prefs
    let manager: DownloadManager

    var service: Service? { musicSource != nil ? Service.named(L("Музичні сервіси")) : Service.detect(url) }
    var musicSource: String? { MusicResolver.source(for: url) }

    init() {
        let p = Prefs()
        prefs = p
        manager = DownloadManager(prefs: p)
        showOnboarding = !prefs.onboarded
        installKeyMonitor()
        startClipboardWatch()
        registerHotKey()
        weeklyUpdate()
    }

    // MARK: дії
    func newDownload() {
        analyzeSeq += 1
        url = ""; info = nil; analyzing = false; analyzeError = nil; statusText = ""
        selectedFormat = nil; selectedEntries = []
        page = .download
        focusURL()
    }

    func focusURL() { page = .download; focusURLTick += 1 }

    func setURL(_ s: String, analyze: Bool) {
        url = s.trimmingCharacters(in: .whitespacesAndNewlines)
        info = nil; analyzeError = nil; selectedFormat = nil; selectedEntries = []
        page = .download
        NSApp.activate(ignoringOtherApps: true)
        if analyze && looksLikeURL(url) { self.analyze() }
    }

    /// Кілька посилань одразу → усі в чергу без аналізу.
    func addBatch(_ urls: [String]) {
        guard !urls.isEmpty else { return }
        let tasks = urls.map { u -> DownloadTask in
            if MusicResolver.source(for: u) != nil {
                // музичне посилання: резолвимо у фоні, а поки що ставимо як задачу-пошук
                let t = DownloadTask(url: u, options: prefs.options(), music: nil)
                resolveMusicLater(t)
                return t
            }
            return DownloadTask(url: u, options: prefs.options())
        }
        manager.addAll(tasks)
        page = .queue
    }

    private func resolveMusicLater(_ placeholder: DownloadTask) {
        Task {
            if let meta = try? await MusicResolver.resolve(placeholder.url) {
                manager.remove(placeholder)
                var opts = prefs.options(); opts.playlist = meta.tracks.count > 1
                manager.addAll(meta.tracks.map { DownloadTask(url: placeholder.url, options: opts, music: $0) })
            }
        }
    }

    func pasteAndAnalyze() {
        showOnboarding = false
        guard let s = SystemActions.clipboardString() else { manager.showToast(L("У буфері обміну немає посилання"), .warning); return }
        let urls = extractURLs(s)
        if urls.count > 1 { addBatch(urls); return }
        guard let first = urls.first ?? (looksLikeURL(s) ? s : nil) else { manager.showToast(L("У буфері обміну немає посилання"), .warning); return }
        setURL(first, analyze: true)
    }

    func importFromFile() {
        guard let path = SystemActions.chooseFile(), let text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        let urls = extractURLs(text)
        if urls.isEmpty { manager.showToast(L("У файлі не знайдено посилань"), .warning) } else { addBatch(urls) }
    }

    func analyze() {
        let target = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard looksLikeURL(target) else { manager.showToast(L("Введіть коректне посилання"), .warning); return }
        analyzeSeq += 1
        let seq = analyzeSeq
        analyzing = true; info = nil; analyzeError = nil; selectedFormat = nil; selectedEntries = []
        statusText = L("Отримую інформацію про медіа…")
        let playlist = prefs.playlist
        let opts = prefs.options()
        let ffmpeg = Tools.ffmpeg(configured: prefs.ffmpegPath)
        let music = musicSource
        Task {
            do {
                var result: MediaInfo
                if let music {
                    let meta = try await MusicResolver.resolve(target)
                    guard !meta.tracks.isEmpty else { throw YTDLPError(message: L("У цьому посиланні не знайдено треків.")) }
                    result = MediaInfo(url: target, title: meta.kind == "track" ? meta.tracks[0].display : meta.title,
                                       uploader: meta.artist, duration: meta.tracks.compactMap(\.duration).reduce(0, +) > 0 ? meta.tracks.compactMap(\.duration).reduce(0, +) : nil,
                                       thumbnail: meta.cover, viewCount: nil, likeCount: nil, uploadDate: nil,
                                       extractor: music, description: meta.kind == "track" ? L("Трек буде знайдено на YouTube і збережено як аудіо з тегами.") : String(format: L("%d треків · кожен буде знайдено на YouTube і збережено як аудіо з тегами."), meta.tracks.count),
                                       isPlaylist: meta.tracks.count > 1, count: meta.tracks.count, music: meta)
                    result.entries = meta.tracks.map { PlaylistEntry(id: $0.id, title: $0.display, url: $0.searchURL, duration: $0.duration) }
                } else {
                    result = try await YTDLP.fetchInfo(url: target, playlist: playlist, options: opts, ffmpeg: ffmpeg)
                }
                guard seq == analyzeSeq else { return }
                withAnimation(.smooth) { info = result; analyzing = false }
                selectedEntries = Set(result.entries.map(\.id))
                statusText = L("Готово до завантаження")
            } catch {
                guard seq == analyzeSeq else { return }
                withAnimation(.smooth) { analyzeError = error.localizedDescription; analyzing = false }
                statusText = music != nil ? "" : L("Можна все одно спробувати завантажити — yt-dlp отримає дані під час завантаження.")
            }
        }
    }

    func download() {
        let target = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard looksLikeURL(target) else { manager.showToast(L("Введіть коректне посилання"), .warning); return }
        let current = info?.url == target ? info : nil

        // Музичний сервіс: по завданню на кожен вибраний трек
        if let meta = current?.music {
            let chosen = meta.tracks.filter { selectedEntries.contains($0.id) }
            guard !chosen.isEmpty else { manager.showToast(L("Виберіть хоча б один трек"), .warning); return }
            var opts = prefs.options(); opts.playlist = chosen.count > 1
            manager.addAll(chosen.map { DownloadTask(url: target, options: opts, music: $0) })
            newDownload(); page = .queue
            return
        }
        // Плейлист із частковим вибором: окреме завдання на кожен елемент
        if let current, current.isPlaylist, !current.entries.isEmpty, selectedEntries.count < current.entries.count {
            let chosen = current.entries.filter { selectedEntries.contains($0.id) }
            guard !chosen.isEmpty else { manager.showToast(L("Виберіть хоча б один елемент"), .warning); return }
            let opts = prefs.options(formatId: selectedFormat, playlistOverride: false)
            manager.addAll(chosen.map { DownloadTask(url: $0.url, options: opts, title: $0.title, duration: $0.duration) })
            newDownload(); page = .queue
            return
        }
        if musicSource != nil && current == nil {
            // не проаналізовано — резолвимо у фоні
            addBatch([target]); newDownload(); return
        }
        let task = DownloadTask(url: target, options: prefs.options(formatId: selectedFormat), info: current)
        manager.add(task)
        newDownload()
        page = .queue
    }

    func handleDrop(_ items: [String]) -> Bool {
        dropTargeted = false
        let urls = items.flatMap(extractURLs)
        guard !urls.isEmpty else { manager.showToast(L("Перетягніть посилання (URL), а не файл"), .warning); return false }
        if urls.count > 1 { addBatch(urls) } else { setURL(urls[0], analyze: true) }
        return true
    }

    /// uniloader://download?url=…  або  uniloader://<url>
    func handleOpenURL(_ u: URL) {
        var target: String? = URLComponents(url: u, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "url" }?.value
        if target == nil, let host = u.host { target = "https://" + host + u.path + (u.query.map { "?" + $0 } ?? "") }
        guard let target, looksLikeURL(target) else { return }
        setURL(target, analyze: true)
    }

    // MARK: ⌘V поза текстовими полями (за фізичною клавішею — працює з будь-якою розкладкою)
    private func installKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command, event.keyCode == 9 else { return event }
            if NSApp.keyWindow?.firstResponder is NSTextView { return event }
            Task { @MainActor in self.pasteAndAnalyze() }
            return nil
        }
    }

    // MARK: стеження за буфером обміну
    func startClipboardWatch() {
        clipboardTimer?.invalidate()
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkClipboard() }
        }
    }

    private func checkClipboard() {
        guard prefs.watchClipboard else { return }
        let pb = NSPasteboard.general
        guard pb.changeCount != lastClipboardChange else { return }
        lastClipboardChange = pb.changeCount
        guard let s = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let link = extractURLs(s).first, link != lastOfferedURL, link != url,
              Service.detect(link).map({ $0.name != Service.generic.name }) == true || MusicResolver.source(for: link) != nil
        else { return }
        lastOfferedURL = link
        if prefs.clipboardAutoAdd {
            addBatch([link])
        } else {
            let svc = MusicResolver.source(for: link) ?? Service.detect(link)?.name ?? ""
            manager.showToast("\(svc): \(Format.truncate(link, 50))", .info, seconds: 8, actionLabel: L("Завантажити")) { [weak self] in
                self?.setURL(link, analyze: true)
            }
        }
    }

    // MARK: глобальний хоткей і швидка панель
    private func registerHotKey() {
        GlobalHotKey.shared.register { NotificationCenter.default.post(name: .openQuickPanel, object: nil) }
    }

    // MARK: щотижневе оновлення yt-dlp
    private func weeklyUpdate() {
        guard prefs.autoUpdate, Date().timeIntervalSince1970 - prefs.lastUpdateCheck > 7 * 24 * 3600 else { return }
        prefs.lastUpdateCheck = Date().timeIntervalSince1970
        Task.detached { [weak self] in
            let (ok, msg, updated) = Tools.updateYtdlp()
            await MainActor.run {
                guard let self else { return }
                if ok && updated { self.manager.showToast("\(L("yt-dlp оновлено")): \(msg)", .success, seconds: 4); ToolInfo.shared.refresh() }
            }
        }
    }
}
