import Foundation

// MARK: - Пошук інструментів

enum Tools {
    static let supportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("UniLoader", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// yt-dlp: копія в Application Support (щоб її можна було оновлювати) → бандл → Homebrew/PATH.
    static func ytdlp() -> String? {
        let local = supportDir.appendingPathComponent("bin/yt-dlp")
        if FileManager.default.isExecutableFile(atPath: local.path) { return local.path }
        if let bundled = Bundle.main.url(forResource: "yt-dlp", withExtension: nil, subdirectory: "bin") {
            try? FileManager.default.createDirectory(at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: bundled, to: local)
            if FileManager.default.isExecutableFile(atPath: local.path) { return local.path }
            return bundled.path
        }
        return which("yt-dlp")
    }

    static func ffmpeg(configured: String) -> String? {
        if !configured.isEmpty {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: configured, isDirectory: &isDir) {
                if isDir.boolValue { return FileManager.default.isExecutableFile(atPath: configured + "/ffmpeg") ? configured + "/ffmpeg" : nil }
                return configured
            }
        }
        if let bundled = Bundle.main.url(forResource: "ffmpeg", withExtension: nil, subdirectory: "bin") { return bundled.path }
        return which("ffmpeg")
    }

    static func which(_ name: String) -> String? {
        for dir in ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"] {
            let p = dir + "/" + name
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        return nil
    }

    static func version(_ path: String?, args: [String] = ["--version"]) -> String {
        guard let path else { return "" }
        let (out, _, _) = Shell.run(path, args, timeout: 20)
        return out.split(separator: "\n").first.map { String($0).replacingOccurrences(of: "ffmpeg version ", with: "").components(separatedBy: " ").first ?? "" } ?? ""
    }

    /// Оновлення yt-dlp (`-U` для standalone-бінарника у Application Support). Повертає (успіх, повідомлення, чи оновилось).
    static func updateYtdlp() -> (Bool, String, Bool) {
        guard let bin = ytdlp() else { return (false, L("yt-dlp не знайдено"), false) }
        let (out, err, code) = Shell.run(bin, ["-U"], timeout: 300)
        let text = out + err
        let updated = text.contains("Updated yt-dlp to") || text.contains("Updating to")
        let tail = text.split(separator: "\n").suffix(2).joined(separator: " ")
        return (code == 0, String(tail.prefix(160)), updated)
    }
}

// MARK: - Синхронний запуск (для коротких команд)

enum Shell {
    static func run(_ path: String, _ args: [String], timeout: Double = 60) -> (String, String, Int32) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.environment = environment()
        let out = Pipe(), err = Pipe()
        p.standardOutput = out; p.standardError = err
        do { try p.run() } catch { return ("", error.localizedDescription, -1) }
        let deadline = Date().addingTimeInterval(timeout)
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        while p.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        if p.isRunning { p.terminate() }
        return (String(decoding: outData, as: UTF8.self), String(decoding: errData, as: UTF8.self), p.terminationStatus)
    }

    static func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        var path = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        if let bin = Bundle.main.resourceURL?.appendingPathComponent("bin").path { path.insert(bin, at: 0) }
        env["PATH"] = path.joined(separator: ":") + ":" + (env["PATH"] ?? "")
        env["PYTHONIOENCODING"] = "utf-8"
        return env
    }

    /// Розбиває рядок додаткових аргументів з урахуванням лапок.
    static func splitArgs(_ s: String) -> [String] {
        var out: [String] = [], cur = "", quote: Character? = nil
        for ch in s {
            if let q = quote { if ch == q { quote = nil } else { cur.append(ch) } }
            else if ch == "\"" || ch == "'" { quote = ch }
            else if ch.isWhitespace { if !cur.isEmpty { out.append(cur); cur = "" } }
            else { cur.append(ch) }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }
}

// MARK: - yt-dlp

struct YTDLPError: LocalizedError {
    let message: String
    var errorDescription: String? { message }

    static func friendly(_ raw: String) -> YTDLPError {
        let lines = raw.split(separator: "\n").map(String.init)
        let msg = (lines.last(where: { $0.contains("ERROR") }) ?? lines.last ?? raw).replacingOccurrences(of: "ERROR: ", with: "")
        let low = msg.lowercased()
        if low.contains("login required") || (low.contains("login") && low.contains("cookies")) {
            return YTDLPError(message: L("Потрібен вхід. Увімкніть cookies із браузера або файл cookies.txt у Налаштуваннях."))
        }
        if low.contains("sign in to confirm") { return YTDLPError(message: L("YouTube вимагає підтвердження. Спробуйте cookies із браузера.")) }
        if low.contains("unsupported url") { return YTDLPError(message: L("Сайт не підтримується або посилання неправильне.")) }
        if low.contains("private") { return YTDLPError(message: L("Приватний контент — потрібні cookies акаунта з доступом.")) }
        if low.contains("ffmpeg") && (low.contains("not found") || low.contains("not installed")) {
            return YTDLPError(message: L("Не знайдено ffmpeg. Вкажіть шлях у Налаштуваннях."))
        }
        if low.contains("http error 404") { return YTDLPError(message: L("Контент не знайдено (404). Можливо, його видалено.")) }
        if low.contains("http error 403") { return YTDLPError(message: L("Доступ заборонено (403). Спробуйте cookies або пізніше.")) }
        return YTDLPError(message: String(msg.prefix(220)))
    }
}

enum YTDLP {
    static func baseArgs(options: DownloadOptions, ffmpeg: String?) -> [String] {
        var a = ["--no-warnings", "--no-colors", "--retries", "5", "--fragment-retries", "5", "--socket-timeout", "30"]
        if !options.cookiesFile.isEmpty { a += ["--cookies", options.cookiesFile] }
        else if !options.cookiesBrowser.isEmpty { a += ["--cookies-from-browser", options.cookiesBrowser] }
        if !options.proxy.isEmpty { a += ["--proxy", options.proxy] }
        if let ffmpeg { a += ["--ffmpeg-location", ffmpeg] }
        return a
    }

    /// Метадані без завантаження (включно з форматами та елементами плейлиста).
    static func fetchInfo(url: String, playlist: Bool, options: DownloadOptions, ffmpeg: String?) async throws -> MediaInfo {
        guard let bin = Tools.ytdlp() else { throw YTDLPError(message: L("Не знайдено yt-dlp.")) }
        var args = baseArgs(options: options, ffmpeg: ffmpeg)
        args += ["--dump-single-json", "--skip-download", playlist ? "--yes-playlist" : "--no-playlist",
                 "--flat-playlist", "--playlist-items", "1:500", url]
        let (out, err, code) = await Task.detached { Shell.run(bin, args, timeout: 120) }.value
        guard code == 0, let data = out.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YTDLPError.friendly(err.isEmpty ? out : err)
        }
        return parse(json, url: url)
    }

    static func parse(_ j: [String: Any], url: String) -> MediaInfo {
        let isPlaylist = (j["_type"] as? String) == "playlist"
        let rawEntries = (j["entries"] as? [[String: Any]]) ?? []
        var thumb = j["thumbnail"] as? String
        if thumb == nil, let thumbs = j["thumbnails"] as? [[String: Any]] { thumb = thumbs.last?["url"] as? String }
        if thumb == nil, isPlaylist, let first = rawEntries.first {
            thumb = first["thumbnail"] as? String ?? ((first["thumbnails"] as? [[String: Any]])?.last?["url"] as? String)
        }
        var duration = j["duration"] as? Double
        if isPlaylist {
            let total = rawEntries.compactMap { $0["duration"] as? Double }.reduce(0, +)
            duration = total > 0 ? total : nil
        }
        let formats: [FormatInfo] = ((j["formats"] as? [[String: Any]]) ?? []).compactMap { f in
            guard let id = f["format_id"] as? String else { return nil }
            let vcodec = f["vcodec"] as? String ?? "none", acodec = f["acodec"] as? String ?? "none"
            if vcodec == "none" && acodec == "none" { return nil }
            if (f["protocol"] as? String)?.contains("mhtml") == true { return nil }
            return FormatInfo(id: id, ext: f["ext"] as? String ?? "", height: f["height"] as? Int, fps: f["fps"] as? Double,
                              vcodec: vcodec, acodec: acodec,
                              filesize: (f["filesize"] as? Int64) ?? (f["filesize_approx"] as? Int64),
                              tbr: f["tbr"] as? Double, note: f["format_note"] as? String ?? f["resolution"] as? String ?? "")
        }
        let entries: [PlaylistEntry] = rawEntries.enumerated().compactMap { i, e in
            guard let u = (e["url"] as? String) ?? (e["webpage_url"] as? String) else { return nil }
            return PlaylistEntry(id: (e["id"] as? String) ?? "\(i)", title: (e["title"] as? String) ?? u, url: u, duration: e["duration"] as? Double)
        }
        return MediaInfo(
            url: url,
            title: (j["title"] as? String) ?? (j["id"] as? String) ?? L("Без назви"),
            uploader: (j["uploader"] as? String) ?? (j["channel"] as? String) ?? (j["uploader_id"] as? String) ?? "",
            duration: duration, thumbnail: thumb,
            viewCount: j["view_count"] as? Int, likeCount: j["like_count"] as? Int,
            uploadDate: j["upload_date"] as? String,
            extractor: (j["extractor_key"] as? String) ?? (j["extractor"] as? String),
            description: String(((j["description"] as? String) ?? "").prefix(400)),
            isPlaylist: isPlaylist, count: isPlaylist ? rawEntries.count : 1,
            formats: formats, entries: entries
        )
    }

    static func downloadArgs(task: DownloadTask, ffmpeg: String?) -> [String] {
        let o = task.options
        var a = baseArgs(options: o, ffmpeg: ffmpeg)
        var tmpl = o.filenameTemplate.isEmpty ? Keys.defaultTemplate : o.filenameTemplate
        if o.playlist && task.music == nil { tmpl = "%(playlist_title,playlist_id|Playlist)s/%(playlist_index&{} - |)s" + tmpl }
        if let m = task.music {
            tmpl = Format.fileSafe("\(m.artist) - \(m.title)") + ".%(ext)s"
            if let album = m.album, o.playlist { tmpl = Format.fileSafe(album) + "/" + tmpl }
        }
        a += ["--newline", "--no-simulate",
              "--progress-template", "download:DL|%(progress.downloaded_bytes)s|%(progress.total_bytes)s|%(progress.total_bytes_estimate)s|%(progress.speed)s|%(progress.eta)s|%(info.playlist_index)s|%(info.n_entries)s",
              "--progress-template", "postprocess:PP|%(progress.status)s|%(progress.postprocessor)s",
              "--print", "before_dl:META|%(title)s|%(thumbnail)s|%(uploader)s|%(duration)s",
              "--print", "after_move:FILE|%(filepath)s",
              "-o", (o.outputDir as NSString).appendingPathComponent(tmpl),
              (o.playlist && task.music == nil) ? "--yes-playlist" : "--no-playlist",
              "--concurrent-fragments", "4", "--no-overwrites", "--continue", "-S", "res,ext"]
        if o.playlist { a += ["--ignore-errors"] }
        if !o.rateLimit.isEmpty { a += ["-r", o.rateLimit] }
        if !o.sections.isEmpty { a += ["--download-sections", "*" + o.sections, "--force-keyframes-at-cuts"] }
        if o.sponsorBlock { a += ["--sponsorblock-remove", "all"] }
        if o.splitChapters { a += ["--split-chapters"] }

        if let m = task.music {
            // Трек із музичного сервісу: аудіо з YouTube + справжні теги (виконавець, назва, альбом)
            a += ["-f", "bestaudio/best", "-x", "--audio-format", o.audioFormat.rawValue, "--audio-quality", "0",
                  "--parse-metadata", "\(clean(m.artist)):%(meta_artist)s",
                  "--parse-metadata", "\(clean(m.title)):%(meta_title)s",
                  "--embed-metadata"]
            if let album = m.album, !album.isEmpty { a += ["--parse-metadata", "\(clean(album)):%(meta_album)s"] }
            if o.embedThumbnail { a += ["--embed-thumbnail"] }
        } else if o.mode == .audio {
            if let f = o.formatId { a += ["-f", "\(f)/bestaudio/best"] } else { a += ["-f", "bestaudio/best"] }
            a += ["-x", "--audio-format", o.audioFormat.rawValue, "--audio-quality", "0"]
            if o.embedThumbnail { a += ["--embed-thumbnail"] }
            if o.embedMetadata { a += ["--embed-metadata"] }
        } else {
            if let f = o.formatId { a += ["-f", "\(f)+bestaudio/\(f)/bv*+ba/b"] }
            else if o.quality == .best { a += ["-f", "bv*+ba/b"] }
            else { let h = o.quality.rawValue; a += ["-f", "bv*[height<=\(h)]+ba/b[height<=\(h)]/bv*+ba/b"] }
            a += ["--merge-output-format", "mp4"]
            if o.subtitles { a += ["--write-subs", "--sub-langs", "uk,en,ru,-live_chat", "--embed-subs"] }
            if o.embedThumbnail { a += ["--embed-thumbnail"] }
            if o.embedMetadata { a += ["--embed-metadata"] }
        }
        a += Shell.splitArgs(o.extraArgs)
        a.append(task.music?.searchURL ?? task.url)
        return a
    }

    private static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: ":", with: " ").replacingOccurrences(of: "%", with: "%%").replacingOccurrences(of: "\n", with: " ")
    }

    enum Event {
        case meta(title: String, thumbnail: String?, uploader: String, duration: Double?)
        case progress(fraction: Double?, detail: String)
        case processing(String)
        case file(String)
        case log(String)
        case finished(exitCode: Int32, stderr: String)
    }

    static func download(task: DownloadTask, ffmpeg: String?, onEvent: @escaping (Event) -> Void) -> Process? {
        guard let bin = Tools.ytdlp() else { onEvent(.finished(exitCode: -1, stderr: L("Не знайдено yt-dlp."))); return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = downloadArgs(task: task, ffmpeg: ffmpeg)
        p.environment = Shell.environment()
        DispatchQueue.main.async { onEvent(.log("$ yt-dlp " + (p.arguments ?? []).map { $0.contains(" ") ? "\"\($0)\"" : $0 }.joined(separator: " "))) }
        let out = Pipe(), err = Pipe()
        p.standardOutput = out; p.standardError = err
        var buffer = Data(), errBuffer = Data()
        var stderr = ""
        let errQueue = DispatchQueue(label: "uniloader.stderr")
        err.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            guard !d.isEmpty else { return }
            errQueue.sync {
                stderr += String(decoding: d, as: UTF8.self)
                errBuffer.append(d)
                while let nl = errBuffer.firstIndex(of: 0x0A) {
                    let line = String(decoding: errBuffer[errBuffer.startIndex..<nl], as: UTF8.self)
                    errBuffer.removeSubrange(errBuffer.startIndex...nl)
                    if !line.isEmpty { DispatchQueue.main.async { onEvent(.log(line)) } }
                }
            }
        }
        out.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            guard !d.isEmpty else { return }
            buffer.append(d)
            while let nl = buffer.firstIndex(of: 0x0A) {
                let line = String(decoding: buffer[buffer.startIndex..<nl], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                buffer.removeSubrange(buffer.startIndex...nl)
                if let e = parseLine(line) { DispatchQueue.main.async { onEvent(e) } }
                else if !line.isEmpty, !line.hasPrefix("DL|") { DispatchQueue.main.async { onEvent(.log(line)) } }
            }
        }
        p.terminationHandler = { proc in
            out.fileHandleForReading.readabilityHandler = nil
            err.fileHandleForReading.readabilityHandler = nil
            let rest = err.fileHandleForReading.readDataToEndOfFile()
            let all = errQueue.sync { stderr + String(decoding: rest, as: UTF8.self) }
            DispatchQueue.main.async { onEvent(.finished(exitCode: proc.terminationStatus, stderr: all)) }
        }
        do { try p.run() } catch {
            onEvent(.finished(exitCode: -1, stderr: error.localizedDescription)); return nil
        }
        return p
    }

    private static func num(_ s: Substring) -> Double? { s == "NA" || s.isEmpty ? nil : Double(s) }

    static func parseLine(_ line: String) -> Event? {
        let parts = line.split(separator: "|", omittingEmptySubsequences: false)
        guard let kind = parts.first else { return nil }
        switch kind {
        case "DL":
            guard parts.count >= 6 else { return nil }
            let done = num(parts[1]) ?? 0
            let total = num(parts[2]) ?? num(parts[3])
            let speed = num(parts[4]), eta = num(parts[5])
            var frac: Double? = nil
            var bits: [String] = []
            if let total, total > 0 {
                frac = min(done / total, 1)
                bits.append(String(format: "%.1f%%", frac! * 100))
                bits.append("\(Format.bytes(done)) / \(Format.bytes(total))")
            } else {
                bits.append(Format.bytes(done))
            }
            if let speed { bits.append(Format.speed(speed)) }
            if let eta { bits.append("ETA " + Format.duration(eta)) }
            if parts.count >= 8, parts[6] != "NA", parts[7] != "NA" { bits.append("[\(parts[6])/\(parts[7])]") }
            return .progress(fraction: frac, detail: bits.joined(separator: " • "))
        case "PP":
            guard parts.count >= 3 else { return nil }
            return parts[1] == "finished" ? nil : .processing(String(parts[2]))
        case "META":
            guard parts.count >= 5 else { return nil }
            return .meta(title: String(parts[1]), thumbnail: parts[2] == "NA" ? nil : String(parts[2]),
                         uploader: parts[3] == "NA" ? "" : String(parts[3]), duration: num(parts[4]))
        case "FILE":
            guard parts.count >= 2 else { return nil }
            return .file(parts.dropFirst().joined(separator: "|"))
        default:
            return nil
        }
    }
}
