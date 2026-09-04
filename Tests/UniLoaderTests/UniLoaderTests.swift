import Testing
import Foundation
@testable import UniLoader

@Suite struct ServiceDetection {
    @Test func knownServices() {
        #expect(Service.detect("https://www.youtube.com/watch?v=abc")?.name == "YouTube")
        #expect(Service.detect("https://music.youtube.com/watch?v=abc")?.name == "YouTube Music")
        #expect(Service.detect("vm.tiktok.com/ZM123")?.name == "TikTok")
        #expect(Service.detect("https://x.com/user/status/1")?.name == "X (Twitter)")
        #expect(Service.detect("https://open.spotify.com/track/1")?.name == "Spotify")
    }
    @Test func genericAndInvalid() {
        #expect(Service.detect("https://example.org/v")?.name == Service.generic.name)
        #expect(Service.detect("hello") == nil)
        #expect(Service.detect("") == nil)
    }
    @Test func everyServiceHasIcon() {
        for s in Service.all { #expect(!s.icon.isEmpty, "\(s.name)") }
    }
}

@Suite struct MusicResolving {
    @Test func sourceDetection() {
        #expect(MusicResolver.source(for: "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC") == "Spotify")
        #expect(MusicResolver.source(for: "https://music.apple.com/ua/album/x/1440913923?i=1440914000") == "Apple Music")
        #expect(MusicResolver.source(for: "https://www.shazam.com/track/40099045/x") == "Shazam")
        #expect(MusicResolver.source(for: "https://www.deezer.com/track/3135556") == "Deezer")
        #expect(MusicResolver.source(for: "https://www.youtube.com/watch?v=abc") == nil)
    }
    @Test func trackQuery() {
        let t = MusicTrack(id: "1", title: "Get Lucky", artist: "Daft Punk", album: nil, duration: nil, cover: nil)
        #expect(t.query == "Daft Punk - Get Lucky")
        #expect(t.searchURL.hasPrefix("ytsearch1:"))
    }
}

@Suite struct ProgressParsing {
    @Test func downloadLine() throws {
        guard case let .progress(fraction, detail)? = YTDLP.parseLine("DL|5000|10000|NA|2048|30|NA|NA") else { Issue.record("no progress"); return }
        #expect(abs(fraction! - 0.5) < 0.001)
        #expect(detail.contains("50.0%"))
        #expect(detail.contains("ETA"))
    }
    @Test func estimateFallbackAndPlaylistIndex() {
        guard case let .progress(fraction, detail)? = YTDLP.parseLine("DL|250|NA|1000|NA|NA|2|7") else { Issue.record("no progress"); return }
        #expect(abs(fraction! - 0.25) < 0.001)
        #expect(detail.contains("[2/7]"))
    }
    @Test func metaAndFile() {
        guard case let .meta(title, thumb, uploader, duration)? = YTDLP.parseLine("META|Hello|NA|Someone|19.5") else { Issue.record("no meta"); return }
        #expect(title == "Hello"); #expect(thumb == nil); #expect(uploader == "Someone"); #expect(duration == 19.5)
        guard case let .file(path)? = YTDLP.parseLine("FILE|/tmp/a|b.mp4") else { Issue.record("no file"); return }
        #expect(path == "/tmp/a|b.mp4")
        #expect(YTDLP.parseLine("random text") == nil)
    }
}

@Suite struct ArgumentBuilding {
    @Test func audioArgs() {
        var o = DownloadOptions(); o.mode = .audio; o.audioFormat = .mp3; o.outputDir = "/tmp/x"
        let a = YTDLP.downloadArgs(task: DownloadTask(url: "https://youtu.be/x", options: o), ffmpeg: "/usr/bin/ffmpeg")
        #expect(a.contains("-x")); #expect(a.contains("mp3")); #expect(a.last == "https://youtu.be/x"); #expect(a.contains("--no-playlist"))
    }
    @Test func explicitFormatAndSections() {
        var o = DownloadOptions(); o.formatId = "137"; o.sections = "00:00:10-00:00:20"; o.sponsorBlock = true; o.rateLimit = "2M"; o.extraArgs = "--no-mtime \"--user-agent\" 'x y'"
        let a = YTDLP.downloadArgs(task: DownloadTask(url: "https://youtu.be/x", options: o), ffmpeg: nil)
        #expect(a.contains("137+bestaudio/137/bv*+ba/b"))
        #expect(a.contains("*00:00:10-00:00:20")); #expect(a.contains("--sponsorblock-remove"))
        #expect(a.contains("2M")); #expect(a.contains("--no-mtime")); #expect(a.contains("x y"))
    }
    @Test func musicTaskUsesSearchAndTags() {
        let m = MusicTrack(id: "1", title: "Song: Two", artist: "Band", album: "Album", duration: nil, cover: nil)
        let a = YTDLP.downloadArgs(task: DownloadTask(url: "https://open.spotify.com/track/1", options: DownloadOptions(), music: m), ffmpeg: nil)
        #expect(a.last!.hasPrefix("ytsearch1:"))
        #expect(a.contains("Band:%(meta_artist)s"))
        #expect(a.contains("Song  Two:%(meta_title)s"))
    }
    @Test func splitArgs() {
        #expect(Shell.splitArgs("a \"b c\" 'd e' f") == ["a", "b c", "d e", "f"])
    }
}

@Suite struct Helpers {
    @Test func extractsURLs() {
        #expect(extractURLs("see https://a.com/x, youtube.com/watch?v=1 and <https://b.org>") == ["https://a.com/x", "https://youtube.com/watch?v=1", "https://b.org"])
    }
    @Test func formatters() {
        #expect(Format.duration(3725) == "1:02:05")
        #expect(Format.duration(65) == "1:05")
        #expect(Format.count(1_500_000).hasPrefix("1.5"))
        #expect(Format.fileSafe("a/b:c*d") == "a-b-c-d")
    }
    @Test func taskRecordRoundTrip() throws {
        let t = DownloadTask(url: "https://youtu.be/x", options: DownloadOptions(), title: "T"); t.status = .downloading; t.filename = "/f"
        let data = try JSONEncoder().encode(t.record())
        let r = try JSONDecoder().decode(TaskRecord.self, from: data).restore()
        #expect(r.status == .queued); #expect(r.title == "T"); #expect(r.filename == "/f")
    }
}
