import Foundation
import Observation

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

// MARK: - Перелічення параметрів

enum Mode: String, CaseIterable, Identifiable, Codable {
    case video, audio
    var id: String { rawValue }
    var label: String { self == .video ? L("Відео") : L("Аудіо") }
}

enum Quality: String, CaseIterable, Identifiable, Codable {
    case best, q2160 = "2160", q1440 = "1440", q1080 = "1080", q720 = "720", q480 = "480", q360 = "360"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .best: return L("Найкраща")
        case .q2160: return "2160p (4K)"
        case .q1440: return "1440p (2K)"
        case .q1080: return "1080p (Full HD)"
        case .q720: return "720p (HD)"
        case .q480: return "480p"
        case .q360: return "360p"
        }
    }
}

enum AudioFormat: String, CaseIterable, Identifiable, Codable {
    case mp3, m4a, opus, wav, flac, best
    var id: String { rawValue }
}

enum TaskStatus: String, Codable {
    case queued, fetching, downloading, processing, done, error, cancelled
    var label: String {
        switch self {
        case .queued: return L("У черзі")
        case .fetching: return L("Отримання даних")
        case .downloading: return L("Завантаження")
        case .processing: return L("Обробка")
        case .done: return L("Готово")
        case .error: return L("Помилка")
        case .cancelled: return L("Скасовано")
        }
    }
    var isActive: Bool { [.queued, .fetching, .downloading, .processing].contains(self) }
}

enum Page: String, CaseIterable, Identifiable, Hashable {
    case download, queue, history, services, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .download: return L("Завантажити")
        case .queue: return L("Черга")
        case .history: return L("Історія")
        case .services: return L("Сервіси")
        case .settings: return L("Налаштування")
        }
    }
    var symbol: String {
        switch self {
        case .download: return "arrow.down.circle.fill"
        case .queue: return "list.bullet"
        case .history: return "clock"
        case .services: return "globe"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Метадані медіа

struct FormatInfo: Identifiable, Hashable {
    let id: String
    let ext: String
    let height: Int?
    let fps: Double?
    let vcodec: String
    let acodec: String
    let filesize: Int64?
    let tbr: Double?
    let note: String

    var hasVideo: Bool { vcodec != "none" && !vcodec.isEmpty }
    var hasAudio: Bool { acodec != "none" && !acodec.isEmpty }

    var label: String {
        var parts: [String] = []
        if hasVideo {
            parts.append(height.map { "\($0)p" } ?? note)
            if let fps, fps > 30 { parts.append("\(Int(fps))fps") }
            parts.append(vcodec.split(separator: ".").first.map(String.init) ?? vcodec)
            if !hasAudio { parts.append(L("без звуку")) }
        } else {
            parts.append(L("аудіо"))
            parts.append(acodec.split(separator: ".").first.map(String.init) ?? acodec)
            if let tbr { parts.append("\(Int(tbr)) kbps") }
        }
        parts.append(ext)
        if let filesize { parts.append("≈ " + Format.bytes(Double(filesize))) }
        return parts.joined(separator: " · ")
    }
}

struct PlaylistEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let url: String
    let duration: Double?
}

/// Трек із музичного сервісу (Spotify, Apple Music, Shazam…): завантажується пошуком на YouTube.
struct MusicTrack: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var artist: String
    var album: String?
    var duration: Double?
    var cover: String?
    var query: String { "\(artist) - \(title)".replacingOccurrences(of: ":", with: " ") }
    var searchURL: String { "ytsearch1:\(query) audio" }
    var display: String { "\(artist) – \(title)" }
}

struct MusicMeta: Hashable {
    var source: String            // Spotify / Apple Music / Shazam / Deezer / …
    var kind: String              // track / album / playlist
    var title: String
    var artist: String
    var cover: String?
    var tracks: [MusicTrack]
}

struct MediaInfo: Equatable {
    var url: String
    var title: String
    var uploader: String
    var duration: Double?
    var thumbnail: String?
    var viewCount: Int?
    var likeCount: Int?
    var uploadDate: String?
    var extractor: String?
    var description: String
    var isPlaylist: Bool
    var count: Int
    var formats: [FormatInfo] = []
    var entries: [PlaylistEntry] = []
    var music: MusicMeta? = nil

    var formatsCount: Int { formats.count }
    var durationText: String { Format.duration(duration) }
    var dateText: String? {
        guard let d = uploadDate, d.count == 8 else { return nil }
        return "\(d.suffix(2)).\(d.dropFirst(4).prefix(2)).\(d.prefix(4))"
    }
}

// MARK: - Параметри завантаження (знімок Prefs у момент додавання в чергу)

struct DownloadOptions: Codable, Hashable {
    var mode: Mode = .video
    var quality: Quality = .best
    var audioFormat: AudioFormat = .mp3
    var outputDir: String = Keys.defaultDir
    var playlist = false
    var subtitles = false
    var embedThumbnail = false
    var embedMetadata = true
    var cookiesBrowser = ""
    var cookiesFile = ""
    var filenameTemplate = Keys.defaultTemplate
    var formatId: String? = nil          // явний формат із списку (переважає над quality)
    var sections = ""                    // "00:01:00-00:02:30"
    var sponsorBlock = false
    var splitChapters = false
    var rateLimit = ""                   // "2M"
    var proxy = ""
    var extraArgs = ""
}

// MARK: - Завдання

@Observable
final class DownloadTask: Identifiable {
    let id: UUID
    let url: String
    let options: DownloadOptions
    let music: MusicTrack?
    let service: Service?

    var title: String
    var thumbnail: String?
    var uploader: String
    var duration: Double?
    var status: TaskStatus = .queued
    var progress: Double = 0
    var detail: String = ""
    var filename: String = ""
    var error: String = ""
    var log: [String] = []
    let addedAt: Date
    var finishedAt: Date?

    @ObservationIgnored var process: Process?
    @ObservationIgnored var cancelRequested = false

    init(id: UUID = UUID(), url: String, options: DownloadOptions, info: MediaInfo? = nil, music: MusicTrack? = nil,
         title: String? = nil, thumbnail: String? = nil, uploader: String? = nil, duration: Double? = nil, addedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.options = options
        self.music = music
        self.service = music != nil ? Service.named(L("Музичні сервіси")) ?? Service.detect(url) : Service.detect(url)
        self.title = title ?? music?.display ?? info?.title ?? url
        self.thumbnail = thumbnail ?? music?.cover ?? info?.thumbnail
        self.uploader = uploader ?? music?.artist ?? info?.uploader ?? ""
        self.duration = duration ?? music?.duration ?? info?.duration
        self.addedAt = addedAt
    }

    var modeLabel: String {
        if music != nil { return "\(L("Аудіо")) · \(options.audioFormat.rawValue.uppercased()) · YouTube" }
        return options.mode == .audio ? "\(L("Аудіо")) · \(options.audioFormat.rawValue.uppercased())" : "\(L("Відео")) · \(options.formatId ?? options.quality.label)"
    }

    func appendLog(_ line: String) {
        log.append(line)
        if log.count > 300 { log.removeFirst(log.count - 300) }
    }

    func historyItem() -> HistoryItem {
        HistoryItem(id: id, url: url, title: title, thumbnail: thumbnail, uploader: uploader, duration: duration,
                    serviceName: service?.name ?? "", serviceIcon: service?.icon ?? "🌐", mode: modeLabel,
                    filename: filename, outputDir: options.outputDir, finishedAt: finishedAt ?? Date())
    }

    func record() -> TaskRecord {
        TaskRecord(id: id, url: url, options: options, music: music, title: title, thumbnail: thumbnail,
                   uploader: uploader, duration: duration, status: status, filename: filename, addedAt: addedAt)
    }
}

/// Codable-знімок завдання для збереження черги між запусками.
struct TaskRecord: Codable {
    var id: UUID
    var url: String
    var options: DownloadOptions
    var music: MusicTrack?
    var title: String
    var thumbnail: String?
    var uploader: String
    var duration: Double?
    var status: TaskStatus
    var filename: String
    var addedAt: Date

    func restore() -> DownloadTask {
        let t = DownloadTask(id: id, url: url, options: options, music: music, title: title, thumbnail: thumbnail,
                             uploader: uploader, duration: duration, addedAt: addedAt)
        t.status = status.isActive ? .queued : status
        t.filename = filename
        if t.status == .done { t.progress = 1 }
        return t
    }
}

struct HistoryItem: Codable, Identifiable, Hashable {
    var id: UUID
    var url: String
    var title: String
    var thumbnail: String?
    var uploader: String
    var duration: Double?
    var serviceName: String
    var serviceIcon: String
    var mode: String
    var filename: String
    var outputDir: String
    var finishedAt: Date
}

// MARK: - Форматування

enum Format {
    static func bytes(_ n: Double?) -> String {
        guard let n, n > 0 else { return "—" }
        let units = [L("Б"), L("КБ"), L("МБ"), L("ГБ"), L("ТБ")]
        var v = n; var i = 0
        while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
        return i == 0 ? String(format: "%.0f %@", v, units[i]) : String(format: "%.1f %@", v, units[i])
    }
    static func speed(_ n: Double?) -> String { n == nil || n == 0 ? "—" : bytes(n) + L("/с") }
    static func duration(_ s: Double?) -> String {
        guard let s else { return "—" }
        let t = Int(s); let h = t / 3600, m = (t % 3600) / 60, sec = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
    static func count(_ n: Int?) -> String {
        guard let n else { return "—" }
        if n >= 1_000_000_000 { return String(format: "%.1f %@", Double(n) / 1e9, L("млрд")) }
        if n >= 1_000_000 { return String(format: "%.1f %@", Double(n) / 1e6, L("млн")) }
        if n >= 1_000 { return String(format: "%.1f %@", Double(n) / 1e3, L("тис.")) }
        return String(n)
    }
    static func truncate(_ s: String, _ limit: Int) -> String {
        let t = s.replacingOccurrences(of: "\n", with: " ")
        return t.count <= limit ? t : String(t.prefix(limit - 1)) + "…"
    }
    static let dateTime: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy HH:mm"; return f
    }()
    /// Прибирає символи, заборонені в іменах файлів.
    static func fileSafe(_ s: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return s.components(separatedBy: bad).joined(separator: "-").trimmingCharacters(in: .whitespaces)
    }
}

func looksLikeURL(_ s: String) -> Bool {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    return !t.isEmpty && !t.contains(" ") && t.contains(".") && !t.hasPrefix("ytsearch")
}

/// Витягує всі http(s)-посилання з довільного тексту (для мультивставки та імпорту з файлу).
func extractURLs(_ text: String) -> [String] {
    var out: [String] = []
    for token in text.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" }) {
        var s = String(token).trimmingCharacters(in: CharacterSet(charactersIn: "<>()[]\"'"))
        if !s.contains("://"), s.contains("."), !s.contains("@") { s = "https://" + s }
        if s.hasPrefix("http://") || s.hasPrefix("https://"), !out.contains(s) { out.append(s) }
    }
    return out
}
