import Foundation

/// Вбудовані перевірки: `UniLoader --self-test`. Працюють без Xcode (XCTest / Swift Testing runner у CLT недоступні).
enum SelfTest {
    private static var failures: [String] = []
    private static var count = 0

    private static func check(_ cond: Bool, _ name: String, file: String = #fileID, line: Int = #line) {
        count += 1
        if !cond { failures.append("\(name) (\(file):\(line))") }
    }

    static func run() -> Int32 {
        // Визначення сервісів
        check(Service.detect("https://www.youtube.com/watch?v=abc")?.name == "YouTube", "detect youtube")
        check(Service.detect("https://music.youtube.com/watch?v=abc")?.name == "YouTube Music", "detect youtube music")
        check(Service.detect("vm.tiktok.com/ZM123")?.name == "TikTok", "detect tiktok short")
        check(Service.detect("https://x.com/user/status/1")?.name == "X (Twitter)", "detect x")
        check(Service.detect("https://example.org/v")?.name == Service.generic.name, "generic")
        check(Service.detect("hello") == nil && Service.detect("") == nil, "invalid")
        check(Service.all.allSatisfy { !$0.icon.isEmpty && !$0.name.isEmpty }, "services have icons")
        // Музичні сервіси
        check(MusicResolver.source(for: "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC") == "Spotify", "spotify source")
        check(MusicResolver.source(for: "https://music.apple.com/ua/album/x/1440913923?i=1440914000") == "Apple Music", "apple source")
        check(MusicResolver.source(for: "https://www.shazam.com/track/40099045/x") == "Shazam", "shazam source")
        check(MusicResolver.source(for: "https://www.deezer.com/track/3135556") == "Deezer", "deezer source")
        check(MusicResolver.source(for: "https://www.youtube.com/watch?v=abc") == nil, "youtube not music")
        let track = MusicTrack(id: "1", title: "Get Lucky", artist: "Daft Punk", album: nil, duration: nil, cover: nil)
        check(track.query == "Daft Punk - Get Lucky" && track.searchURL.hasPrefix("ytsearch1:"), "track query")
        // Парсер прогресу
        if case let .progress(f, d)? = YTDLP.parseLine("DL|5000|10000|NA|2048|30|NA|NA") { check(abs(f! - 0.5) < 0.001 && d.contains("50.0%") && d.contains("ETA"), "progress line") } else { check(false, "progress parse") }
        if case let .progress(f, d)? = YTDLP.parseLine("DL|250|NA|1000|NA|NA|2|7") { check(abs(f! - 0.25) < 0.001 && d.contains("[2/7]"), "estimate+index") } else { check(false, "estimate parse") }
        if case let .meta(t, th, u, dur)? = YTDLP.parseLine("META|Hello|NA|Someone|19.5") { check(t == "Hello" && th == nil && u == "Someone" && dur == 19.5, "meta line") } else { check(false, "meta parse") }
        if case let .file(p)? = YTDLP.parseLine("FILE|/tmp/a|b.mp4") { check(p == "/tmp/a|b.mp4", "file line") } else { check(false, "file parse") }
        check(YTDLP.parseLine("random text") == nil, "unknown line")
        // Аргументи
        var o = DownloadOptions(); o.mode = .audio; o.audioFormat = .mp3; o.outputDir = "/tmp/x"
        var a = YTDLP.downloadArgs(task: DownloadTask(url: "https://youtu.be/x", options: o), ffmpeg: "/usr/bin/ffmpeg")
        check(a.contains("-x") && a.contains("mp3") && a.last == "https://youtu.be/x" && a.contains("--no-playlist"), "audio args")
        o = DownloadOptions(); o.formatId = "137"; o.sections = "00:00:10-00:00:20"; o.sponsorBlock = true; o.rateLimit = "2M"; o.extraArgs = "--no-mtime \"--user-agent\" 'x y'"
        a = YTDLP.downloadArgs(task: DownloadTask(url: "https://youtu.be/x", options: o), ffmpeg: nil)
        check(a.contains("137+bestaudio/137/bv*+ba/b") && a.contains("*00:00:10-00:00:20") && a.contains("--sponsorblock-remove") && a.contains("2M") && a.contains("--no-mtime") && a.contains("x y"), "advanced args")
        let m = MusicTrack(id: "1", title: "Song: Two", artist: "Band", album: "Album", duration: nil, cover: nil)
        a = YTDLP.downloadArgs(task: DownloadTask(url: "https://open.spotify.com/track/1", options: DownloadOptions(), music: m), ffmpeg: nil)
        check(a.last!.hasPrefix("ytsearch1:") && a.contains("Band:%(meta_artist)s") && a.contains("Song  Two:%(meta_title)s"), "music args")
        check(Shell.splitArgs("a \"b c\" 'd e' f") == ["a", "b c", "d e", "f"], "split args")
        // Хелпери
        check(extractURLs("see https://a.com/x, youtube.com/watch?v=1 and <https://b.org>") == ["https://a.com/x", "https://youtube.com/watch?v=1", "https://b.org"], "extract urls")
        check(Format.duration(3725) == "1:02:05" && Format.duration(65) == "1:05", "duration")
        check(Format.count(1_500_000).hasPrefix("1.5"), "count")
        check(Format.fileSafe("a/b:c*d") == "a-b-c-d", "file safe")
        let t = DownloadTask(url: "https://youtu.be/x", options: DownloadOptions(), title: "T"); t.status = .downloading; t.filename = "/f"
        if let data = try? JSONEncoder().encode(t.record()), let r = try? JSONDecoder().decode(TaskRecord.self, from: data) {
            let restored = r.restore()
            check(restored.status == .queued && restored.title == "T" && restored.filename == "/f", "record round trip")
        } else { check(false, "record encode") }

        print("Self-test: \(count - failures.count)/\(count) passed")
        failures.forEach { print("  ✗ \($0)") }
        return failures.isEmpty ? 0 : 1
    }
}
