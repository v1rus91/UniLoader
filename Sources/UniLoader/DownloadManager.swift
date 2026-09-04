import Foundation
import Observation
import AppKit
import UserNotifications

// MARK: - Тост

struct Toast: Equatable {
    enum Kind { case success, info, warning, error }
    let id = UUID()
    let text: String
    let kind: Kind
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
    static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
}

// MARK: - Менеджер завантажень

@MainActor
@Observable
final class DownloadManager {
    var tasks: [DownloadTask] = []
    var history: [HistoryItem] = []
    var toast: Toast?
    private var toastJob: Task<Void, Never>?
    private var saveJob: Task<Void, Never>?
    var notificationsGranted = false

    private let historyURL = Tools.supportDir.appendingPathComponent("history.json")
    private let queueURL = Tools.supportDir.appendingPathComponent("queue.json")
    private let prefs: Prefs

    init(prefs: Prefs) {
        self.prefs = prefs
        loadHistory()
        restoreQueue()
        requestNotifications()
    }

    var activeCount: Int { tasks.filter { $0.status.isActive }.count }
    var runningCount: Int { tasks.filter { [.fetching, .downloading, .processing].contains($0.status) }.count }
    var maxWorkers: Int { max(1, min(prefs.maxWorkers, 4)) }

    func showToast(_ text: String, _ kind: Toast.Kind = .success, seconds: Double = 2.4, actionLabel: String? = nil, action: (() -> Void)? = nil) {
        toastJob?.cancel()
        toast = Toast(text: text, kind: kind, actionLabel: actionLabel, action: action)
        toastJob = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    // MARK: черга
    func add(_ task: DownloadTask, quiet: Bool = false) {
        tasks.insert(task, at: 0)
        if !quiet { showToast(L("Додано в чергу"), .info) }
        pump()
        scheduleSave()
    }

    func addAll(_ list: [DownloadTask]) {
        for t in list.reversed() { tasks.insert(t, at: 0) }
        showToast(String(format: L("Додано в чергу: %d"), list.count), .info)
        pump()
        scheduleSave()
    }

    func cancel(_ task: DownloadTask) {
        guard task.status.isActive else { return }
        task.cancelRequested = true
        if let p = task.process, p.isRunning {
            p.terminate()
        } else if task.status == .queued {
            task.status = .cancelled
            task.detail = L("Скасовано користувачем")
            scheduleSave()
        }
    }

    func cancelAll() { tasks.forEach(cancel) }

    func remove(_ task: DownloadTask) {
        cancel(task)
        tasks.removeAll { $0.id == task.id }
        scheduleSave()
    }

    func clearFinished() { tasks.removeAll { !$0.status.isActive }; scheduleSave() }

    func retry(_ old: DownloadTask) {
        var opts = old.options
        opts.cookiesBrowser = prefs.cookiesBrowser
        opts.cookiesFile = prefs.cookiesFile
        let new = DownloadTask(url: old.url, options: opts, music: old.music, title: old.title == old.url ? nil : old.title,
                               thumbnail: old.thumbnail, uploader: old.uploader, duration: old.duration)
        tasks.removeAll { $0.id == old.id }
        add(new)
    }

    private func pump() {
        guard runningCount < maxWorkers,
              let next = tasks.last(where: { $0.status == .queued && !$0.cancelRequested }) else { updateBadge(); return }
        start(next)
        pump()
    }

    private func start(_ task: DownloadTask) {
        task.status = .fetching
        task.detail = L("Отримання інформації…")
        try? FileManager.default.createDirectory(atPath: task.options.outputDir, withIntermediateDirectories: true)
        let ffmpeg = Tools.ffmpeg(configured: prefs.ffmpegPath)
        updateBadge()
        task.process = YTDLP.download(task: task, ffmpeg: ffmpeg) { [weak self] event in
            guard let self else { return }
            switch event {
            case let .meta(title, thumb, uploader, duration):
                if task.music == nil {
                    if task.title == task.url || task.title.isEmpty { task.title = title }
                    if task.thumbnail == nil { task.thumbnail = thumb }
                    if task.uploader.isEmpty { task.uploader = uploader }
                } else {
                    task.appendLog("→ YouTube: \(title)")
                    if task.thumbnail == nil { task.thumbnail = thumb }
                }
                if task.duration == nil { task.duration = duration }
            case let .progress(fraction, detail):
                task.status = .downloading
                if let fraction { task.progress = fraction }
                task.detail = detail
            case let .processing(name):
                task.status = .processing
                task.progress = 1
                task.detail = "\(L("Обробка ffmpeg")): \(name)"
            case let .file(path):
                task.filename = path
            case let .log(line):
                task.appendLog(line)
            case let .finished(code, stderr):
                self.finish(task, code: code, stderr: stderr)
            }
        }
    }

    private func finish(_ task: DownloadTask, code: Int32, stderr: String) {
        task.process = nil
        task.finishedAt = Date()
        if task.cancelRequested {
            task.status = .cancelled
            task.detail = L("Скасовано користувачем")
        } else if code == 0 {
            task.status = .done
            task.progress = 1
            let name = (task.filename as NSString).lastPathComponent
            task.detail = "\(L("Збережено")): \(name.isEmpty ? task.options.outputDir : name)"
            history.insert(task.historyItem(), at: 0)
            if history.count > 300 { history.removeLast(history.count - 300) }
            saveHistory()
            showToast("\(L("Готово")): \(Format.truncate(task.title, 60))", .success)
            notify(title: L("Завантажено"), body: task.title, ok: true)
        } else {
            task.status = .error
            task.error = YTDLPError.friendly(stderr).message
            task.detail = task.error
            showToast(task.error, .error, seconds: 5)
            notify(title: L("Помилка завантаження"), body: "\(Format.truncate(task.title, 60)): \(task.error)", ok: false)
        }
        scheduleSave()
        pump()
    }

    // MARK: сповіщення та Dock
    private func requestNotifications() {
        guard Bundle.main.bundleIdentifier != nil else { return }   // поза .app (swift run) центр сповіщень недоступний
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] ok, _ in
            Task { @MainActor in self?.notificationsGranted = ok }
        }
    }

    private func notify(title: String, body: String, ok: Bool) {
        if prefs.sound { NSSound(named: ok ? "Glass" : "Basso")?.play() }
        guard prefs.notifications, notificationsGranted, !NSApp.isActive || NSApp.keyWindow == nil else { return }
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body; c.sound = nil
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    private func updateBadge() {
        let n = tasks.filter { [.fetching, .downloading, .processing, .queued].contains($0.status) }.count
        NSApp.dockTile.badgeLabel = n > 0 ? String(n) : nil
    }

    // MARK: збереження черги
    private func scheduleSave() {
        updateBadge()
        saveJob?.cancel()
        saveJob = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.saveQueue()
        }
    }

    func saveQueue() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        let records = tasks.map { $0.record() }
        if let data = try? enc.encode(records) { try? data.write(to: queueURL) }
    }

    private func restoreQueue() {
        guard let data = try? Data(contentsOf: queueURL) else { return }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        guard let records = try? dec.decode([TaskRecord].self, from: data) else { return }
        tasks = records.map { $0.restore() }
        let resumed = tasks.filter { $0.status == .queued }.count
        if resumed > 0 {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.showToast(String(format: L("Відновлено незавершених завантажень: %d"), resumed), .info)
                self.pump()
            }
        }
    }

    // MARK: історія
    func loadHistory() {
        guard let data = try? Data(contentsOf: historyURL) else { return }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        history = (try? dec.decode([HistoryItem].self, from: data)) ?? []
    }

    func saveHistory() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970; enc.outputFormatting = .prettyPrinted
        if let data = try? enc.encode(history) { try? data.write(to: historyURL) }
    }

    func clearHistory() {
        history = []
        saveHistory()
        showToast(L("Історію очищено"), .info)
    }
}

// MARK: - Системні дії

enum SystemActions {
    static func open(_ path: String) -> Bool {
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return false }
        return NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    static func reveal(_ path: String) {
        var p = path
        if p.isEmpty || !FileManager.default.fileExists(atPath: p) { p = (path as NSString).deletingLastPathComponent }
        guard FileManager.default.fileExists(atPath: p) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: p)])
    }

    static func chooseFolder(initial: String) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: initial)
        panel.prompt = L("Обрати")
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    static func chooseFile(types: [String] = []) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = L("Обрати")
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    static func clipboardString() -> String? {
        NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}
