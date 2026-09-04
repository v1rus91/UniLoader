import Foundation
import Observation

enum Keys {
    static let defaultDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/UniLoader").path
    static let defaultTemplate = "%(title).150B [%(id)s].%(ext)s"
}

/// Налаштування у UserDefaults, спостережувані SwiftUI.
@Observable
final class Prefs {
    private let d = UserDefaults.standard

    var appearance: String { didSet { d.set(appearance, forKey: "appearance") } }
    var downloadDir: String { didSet { d.set(downloadDir, forKey: "downloadDir") } }
    var maxWorkers: Int { didSet { d.set(maxWorkers, forKey: "maxWorkers") } }
    var cookiesBrowser: String { didSet { d.set(cookiesBrowser, forKey: "cookiesBrowser") } }
    var cookiesFile: String { didSet { d.set(cookiesFile, forKey: "cookiesFile") } }
    var ffmpegPath: String { didSet { d.set(ffmpegPath, forKey: "ffmpegPath") } }
    var mode: Mode { didSet { d.set(mode.rawValue, forKey: "defaultMode") } }
    var quality: Quality { didSet { d.set(quality.rawValue, forKey: "defaultQuality") } }
    var audioFormat: AudioFormat { didSet { d.set(audioFormat.rawValue, forKey: "defaultAudioFormat") } }
    var embedMetadata: Bool { didSet { d.set(embedMetadata, forKey: "embedMetadata") } }
    var embedThumbnail: Bool { didSet { d.set(embedThumbnail, forKey: "embedThumbnail") } }
    var subtitles: Bool { didSet { d.set(subtitles, forKey: "subtitles") } }
    var playlist: Bool { didSet { d.set(playlist, forKey: "playlist") } }
    var template: String { didSet { d.set(template, forKey: "filenameTemplate") } }
    var onboarded: Bool { didSet { d.set(onboarded, forKey: "onboarded") } }
    // нові
    var watchClipboard: Bool { didSet { d.set(watchClipboard, forKey: "watchClipboard") } }
    var clipboardAutoAdd: Bool { didSet { d.set(clipboardAutoAdd, forKey: "clipboardAutoAdd") } }
    var menuBar: Bool { didSet { d.set(menuBar, forKey: "menuBar") } }
    var notifications: Bool { didSet { d.set(notifications, forKey: "notifications") } }
    var sound: Bool { didSet { d.set(sound, forKey: "sound") } }
    var autoUpdate: Bool { didSet { d.set(autoUpdate, forKey: "autoUpdate") } }
    var lastUpdateCheck: Double { didSet { d.set(lastUpdateCheck, forKey: "lastUpdateCheck") } }
    var sponsorBlock: Bool { didSet { d.set(sponsorBlock, forKey: "sponsorBlock") } }
    var splitChapters: Bool { didSet { d.set(splitChapters, forKey: "splitChapters") } }
    var sections: String { didSet { d.set(sections, forKey: "sections") } }
    var rateLimit: String { didSet { d.set(rateLimit, forKey: "rateLimit") } }
    var proxy: String { didSet { d.set(proxy, forKey: "proxy") } }
    var extraArgs: String { didSet { d.set(extraArgs, forKey: "extraArgs") } }

    init() {
        let d = UserDefaults.standard
        d.register(defaults: ["appearance": "system", "downloadDir": Keys.defaultDir, "maxWorkers": 2, "defaultMode": "video",
                              "defaultQuality": "best", "defaultAudioFormat": "mp3", "embedMetadata": true, "filenameTemplate": Keys.defaultTemplate,
                              "watchClipboard": true, "menuBar": true, "notifications": true, "sound": true, "autoUpdate": true])
        appearance = d.string(forKey: "appearance") ?? "system"
        downloadDir = d.string(forKey: "downloadDir") ?? Keys.defaultDir
        maxWorkers = d.integer(forKey: "maxWorkers")
        cookiesBrowser = d.string(forKey: "cookiesBrowser") ?? ""
        cookiesFile = d.string(forKey: "cookiesFile") ?? ""
        ffmpegPath = d.string(forKey: "ffmpegPath") ?? ""
        mode = Mode(rawValue: d.string(forKey: "defaultMode") ?? "") ?? .video
        quality = Quality(rawValue: d.string(forKey: "defaultQuality") ?? "") ?? .best
        audioFormat = AudioFormat(rawValue: d.string(forKey: "defaultAudioFormat") ?? "") ?? .mp3
        embedMetadata = d.bool(forKey: "embedMetadata")
        embedThumbnail = d.bool(forKey: "embedThumbnail")
        subtitles = d.bool(forKey: "subtitles")
        playlist = d.bool(forKey: "playlist")
        template = d.string(forKey: "filenameTemplate") ?? Keys.defaultTemplate
        onboarded = d.bool(forKey: "onboarded")
        watchClipboard = d.bool(forKey: "watchClipboard")
        clipboardAutoAdd = d.bool(forKey: "clipboardAutoAdd")
        menuBar = d.bool(forKey: "menuBar")
        notifications = d.bool(forKey: "notifications")
        sound = d.bool(forKey: "sound")
        autoUpdate = d.bool(forKey: "autoUpdate")
        lastUpdateCheck = d.double(forKey: "lastUpdateCheck")
        sponsorBlock = d.bool(forKey: "sponsorBlock")
        splitChapters = d.bool(forKey: "splitChapters")
        sections = d.string(forKey: "sections") ?? ""
        rateLimit = d.string(forKey: "rateLimit") ?? ""
        proxy = d.string(forKey: "proxy") ?? ""
        extraArgs = d.string(forKey: "extraArgs") ?? ""
    }

    /// Знімок опцій для нового завдання.
    func options(formatId: String? = nil, playlistOverride: Bool? = nil) -> DownloadOptions {
        DownloadOptions(mode: mode, quality: quality, audioFormat: audioFormat, outputDir: downloadDir,
                        playlist: playlistOverride ?? playlist, subtitles: subtitles, embedThumbnail: embedThumbnail,
                        embedMetadata: embedMetadata, cookiesBrowser: cookiesBrowser, cookiesFile: cookiesFile,
                        filenameTemplate: template, formatId: formatId, sections: sections, sponsorBlock: sponsorBlock,
                        splitChapters: splitChapters, rateLimit: rateLimit, proxy: proxy, extraArgs: extraArgs)
    }
}
