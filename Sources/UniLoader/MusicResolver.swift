import Foundation

/// Розбирає посилання музичних сервісів (Spotify, Apple Music, Shazam, Deezer, Tidal, Яндекс Музика, Amazon Music…)
/// у список треків «виконавець – назва». Сам контент захищений DRM, тому далі трек шукається на YouTube.
enum MusicResolver {
    static let hosts: [String: String] = [
        "open.spotify.com": "Spotify", "spotify.link": "Spotify", "spotify.com": "Spotify",
        "music.apple.com": "Apple Music", "itunes.apple.com": "Apple Music",
        "shazam.com": "Shazam",
        "deezer.com": "Deezer", "deezer.page.link": "Deezer",
        "tidal.com": "Tidal", "listen.tidal.com": "Tidal",
        "music.yandex.ru": "Яндекс Музика", "music.yandex.com": "Яндекс Музика",
        "music.amazon.com": "Amazon Music", "amazon.com": "Amazon Music",
        "qobuz.com": "Qobuz", "napster.com": "Napster", "boomplay.com": "Boomplay", "anghami.com": "Anghami",
        "genius.com": "Genius", "last.fm": "Last.fm", "musicbrainz.org": "MusicBrainz", "discogs.com": "Discogs",
    ]

    static func source(for url: String) -> String? {
        guard let host = URL(string: url.contains("://") ? url : "https://" + url)?.host?.lowercased() else { return nil }
        let h = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        for (k, v) in hosts where h == k || h.hasSuffix("." + k) { return v }
        return nil
    }

    static func resolve(_ url: String) async throws -> MusicMeta {
        guard let src = source(for: url) else { throw YTDLPError(message: L("Це не посилання музичного сервісу.")) }
        switch src {
        case "Spotify": return try await spotify(url)
        case "Apple Music": return try await appleMusic(url)
        case "Shazam": return try await shazam(url)
        case "Deezer": return try await deezer(url)
        default: return try await openGraph(url, source: src)
        }
    }

    // MARK: HTTP
    static let browserUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    /// Деякі сайти (Shazam) віддають серверний HTML з OpenGraph лише «не-браузерам», інші — навпаки.
    static let ogUserAgents = ["curl/8.7.1", "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)", browserUA]

    private static func get(_ url: String, headers: [String: String] = [:], userAgent: String = browserUA) async throws -> Data {
        guard let u = URL(string: url) else { throw YTDLPError(message: L("Неправильне посилання.")) }
        var req = URLRequest(url: u, timeoutInterval: 20)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let code = (resp as? HTTPURLResponse)?.statusCode, (200..<300).contains(code) else {
            throw YTDLPError(message: String(format: L("Сервіс відповів помилкою (%d)."), (resp as? HTTPURLResponse)?.statusCode ?? 0))
        }
        return data
    }

    private static func json(_ data: Data) -> Any? { try? JSONSerialization.jsonObject(with: data) }

    /// Значення <meta property/name="prop" content="…"> незалежно від порядку атрибутів і лапок.
    private static func meta(_ html: String, _ prop: String) -> String? {
        guard let tagRe = try? NSRegularExpression(pattern: "<meta\\b[^>]*>", options: [.caseInsensitive]),
              let attrRe = try? NSRegularExpression(pattern: "([a-zA-Z:-]+)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)')") else { return nil }
        let ns = html as NSString
        for m in tagRe.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let tag = ns.substring(with: m.range)
            var attrs: [String: String] = [:]
            let tns = tag as NSString
            for a in attrRe.matches(in: tag, range: NSRange(location: 0, length: tns.length)) {
                let key = tns.substring(with: a.range(at: 1)).lowercased()
                let val = a.range(at: 2).location != NSNotFound ? tns.substring(with: a.range(at: 2)) : tns.substring(with: a.range(at: 3))
                attrs[key] = val
            }
            if (attrs["property"] == prop || attrs["name"] == prop), let c = attrs["content"], !c.isEmpty { return decodeEntities(c) }
        }
        return nil
    }

    private static func decodeEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&#x27;", with: "'")
         .replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&quot;", with: "\"")
         .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
    }

    // MARK: Spotify — сторінка embed містить JSON із треками (без API-ключа)
    private static func spotify(_ url: String) async throws -> MusicMeta {
        var link = url
        if link.contains("spotify.link") {   // короткі посилання → редирект
            if let u = URL(string: link), let final = try? await URLSession.shared.data(from: u).1.url?.absoluteString { link = final }
        }
        guard let m = link.range(of: #"(track|album|playlist|episode)/([A-Za-z0-9]+)"#, options: .regularExpression) else {
            throw YTDLPError(message: L("Підтримуються посилання Spotify на трек, альбом або плейлист."))
        }
        let path = String(link[m])
        let kind = String(path.split(separator: "/")[0]), id = String(path.split(separator: "/")[1])
        let html = String(decoding: try await get("https://open.spotify.com/embed/\(kind)/\(id)"), as: UTF8.self)
        guard let s = html.range(of: "<script id=\"__NEXT_DATA__\" type=\"application/json\">"),
              let e = html[s.upperBound...].range(of: "</script>"),
              let root = json(Data(html[s.upperBound..<e.lowerBound].utf8)) as? [String: Any],
              let entity = ((root["props"] as? [String: Any])?["pageProps"] as? [String: Any]).flatMap({ ($0["state"] as? [String: Any])?["data"] as? [String: Any] })?["entity"] as? [String: Any]
        else { throw YTDLPError(message: L("Не вдалося прочитати дані Spotify. Спробуйте пізніше.")) }

        let title = entity["title"] as? String ?? entity["name"] as? String ?? ""
        let cover = ((entity["visualIdentity"] as? [String: Any])?["image"] as? [[String: Any]])?.last?["url"] as? String
            ?? ((entity["coverArt"] as? [String: Any])?["sources"] as? [[String: Any]])?.last?["url"] as? String
        let subtitle = entity["subtitle"] as? String ?? ""
        if kind == "track" || kind == "episode" {
            let artist = ((entity["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: ", ")).flatMap { $0.isEmpty ? nil : $0 } ?? subtitle
            let dur = (entity["duration"] as? Double).map { $0 / 1000 }
            let t = MusicTrack(id: id, title: title, artist: artist, album: nil, duration: dur, cover: cover)
            return MusicMeta(source: "Spotify", kind: "track", title: title, artist: artist, cover: cover, tracks: [t])
        }
        let list = (entity["trackList"] as? [[String: Any]]) ?? []
        let tracks = list.enumerated().map { i, t in
            MusicTrack(id: (t["uri"] as? String) ?? "\(id)-\(i)", title: t["title"] as? String ?? "", artist: t["subtitle"] as? String ?? subtitle,
                       album: kind == "album" ? title : nil, duration: (t["duration"] as? Double).map { $0 / 1000 }, cover: cover)
        }
        return MusicMeta(source: "Spotify", kind: kind, title: title, artist: subtitle, cover: cover, tracks: tracks)
    }

    // MARK: Apple Music — iTunes Lookup API (трек, альбом) + JSON сторінки (плейлист)
    private static func appleMusic(_ url: String) async throws -> MusicMeta {
        guard let u = URL(string: url) else { throw YTDLPError(message: L("Неправильне посилання.")) }
        let country = u.pathComponents.dropFirst().first.flatMap { $0.count == 2 ? $0 : nil } ?? "us"
        let trackId = URLComponents(url: u, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "i" }?.value
        let last = u.lastPathComponent
        if u.path.contains("/playlist/") {
            return try await applePlaylist(url)
        }
        let lookupId = trackId ?? (Int(last) != nil ? last : nil)
        guard let lookupId else { throw YTDLPError(message: L("Підтримуються посилання Apple Music на пісню, альбом або плейлист.")) }
        let data = try await get("https://itunes.apple.com/lookup?id=\(lookupId)&entity=song&country=\(country)&limit=200")
        guard let root = json(data) as? [String: Any], let results = root["results"] as? [[String: Any]], !results.isEmpty else {
            throw YTDLPError(message: L("Apple Music не повернув дані для цього посилання."))
        }
        let songs = results.filter { ($0["wrapperType"] as? String) == "track" }
        let collection = results.first { ($0["wrapperType"] as? String) == "collection" }
        func track(_ s: [String: Any]) -> MusicTrack {
            MusicTrack(id: String(describing: s["trackId"] ?? UUID().uuidString), title: s["trackName"] as? String ?? "",
                       artist: s["artistName"] as? String ?? "", album: s["collectionName"] as? String,
                       duration: (s["trackTimeMillis"] as? Double).map { $0 / 1000 },
                       cover: (s["artworkUrl100"] as? String)?.replacingOccurrences(of: "100x100", with: "600x600"))
        }
        if trackId != nil, let s = songs.first(where: { String(describing: $0["trackId"] ?? "") == trackId! }) ?? songs.first {
            let t = track(s)
            return MusicMeta(source: "Apple Music", kind: "track", title: t.title, artist: t.artist, cover: t.cover, tracks: [t])
        }
        let tracks = songs.map(track)
        let title = collection?["collectionName"] as? String ?? tracks.first?.album ?? ""
        let artist = collection?["artistName"] as? String ?? tracks.first?.artist ?? ""
        let cover = (collection?["artworkUrl100"] as? String)?.replacingOccurrences(of: "100x100", with: "600x600") ?? tracks.first?.cover
        return MusicMeta(source: "Apple Music", kind: "album", title: title, artist: artist, cover: cover, tracks: tracks)
    }

    private static func applePlaylist(_ url: String) async throws -> MusicMeta {
        let html = String(decoding: try await get(url), as: UTF8.self)
        // Сторінка містить <script id="serialized-server-data">[...]</script> із треками
        guard let s = html.range(of: "<script type=\"application/json\" id=\"serialized-server-data\">"),
              let e = html[s.upperBound...].range(of: "</script>"),
              let root = json(Data(html[s.upperBound..<e.lowerBound].utf8)) else {
            return try await openGraph(url, source: "Apple Music")
        }
        var tracks: [MusicTrack] = []
        func walk(_ node: Any) {
            if let d = node as? [String: Any] {
                if let title = d["title"] as? String, let artist = (d["artistName"] as? String) ?? (d["subtitleLinks"] as? [[String: Any]])?.first?["title"] as? String,
                   d["duration"] != nil || d["trackNumber"] != nil {
                    let cover = ((d["artwork"] as? [String: Any])?["dictionary"] as? [String: Any])?["url"] as? String
                    let id = (d["id"] as? String) ?? "\(tracks.count)"
                    if !tracks.contains(where: { $0.id == id }) {
                        tracks.append(MusicTrack(id: id, title: title, artist: artist, album: nil,
                                                 duration: (d["duration"] as? Double).map { $0 > 10000 ? $0 / 1000 : $0 },
                                                 cover: cover?.replacingOccurrences(of: "{w}x{h}{c}.{f}", with: "600x600bb.jpg")))
                    }
                }
                d.values.forEach(walk)
            } else if let a = node as? [Any] { a.forEach(walk) }
        }
        walk(root)
        guard !tracks.isEmpty else { return try await openGraph(url, source: "Apple Music") }
        var title = meta(html, "og:title")?.components(separatedBy: " - ").first ?? L("Плейлист")
        for suffix in [" on Apple Music", " – Apple Music", " - Apple Music"] { if let r = title.range(of: suffix) { title = String(title[..<r.lowerBound]) } }
        return MusicMeta(source: "Apple Music", kind: "playlist", title: title, artist: "", cover: meta(html, "og:image"), tracks: tracks)
    }

    // MARK: Shazam — публічний discovery API + OpenGraph
    private static func shazam(_ url: String) async throws -> MusicMeta {
        if false, let m = url.range(of: #"/(track|song)/(\d+)"#, options: .regularExpression) {
            let id = String(url[m]).split(separator: "/").last.map(String.init) ?? ""
            if let data = try? await get("https://www.shazam.com/discovery/v5/en-US/US/web/-/track/\(id)?shazamapiversion=v3&video=v3"),
               let root = json(data) as? [String: Any], let title = root["title"] as? String {
                let artist = root["subtitle"] as? String ?? ""
                let cover = ((root["images"] as? [String: Any])?["coverarthq"] as? String) ?? ((root["images"] as? [String: Any])?["coverart"] as? String)
                let t = MusicTrack(id: id, title: title, artist: artist, album: nil, duration: nil, cover: cover)
                return MusicMeta(source: "Shazam", kind: "track", title: title, artist: artist, cover: cover, tracks: [t])
            }
        }
        return try await openGraph(url, source: "Shazam")
    }

    // MARK: Deezer — відкритий API без ключа
    private static func deezer(_ url: String) async throws -> MusicMeta {
        var link = url
        if link.contains("deezer.page.link"), let u = URL(string: link), let final = try? await URLSession.shared.data(from: u).1.url?.absoluteString { link = final }
        guard let m = link.range(of: #"(track|album|playlist)/(\d+)"#, options: .regularExpression) else {
            throw YTDLPError(message: L("Підтримуються посилання Deezer на трек, альбом або плейлист."))
        }
        let parts = link[m].split(separator: "/"); let kind = String(parts[0]), id = String(parts[1])
        guard let root = json(try await get("https://api.deezer.com/\(kind)/\(id)")) as? [String: Any], root["error"] == nil else {
            throw YTDLPError(message: L("Deezer не повернув дані для цього посилання."))
        }
        func track(_ t: [String: Any], album: String?) -> MusicTrack {
            MusicTrack(id: String(describing: t["id"] ?? ""), title: t["title"] as? String ?? "",
                       artist: (t["artist"] as? [String: Any])?["name"] as? String ?? "", album: album ?? (t["album"] as? [String: Any])?["title"] as? String,
                       duration: t["duration"] as? Double, cover: ((t["album"] as? [String: Any])?["cover_big"] as? String))
        }
        if kind == "track" {
            let t = track(root, album: nil)
            return MusicMeta(source: "Deezer", kind: "track", title: t.title, artist: t.artist, cover: t.cover, tracks: [t])
        }
        let title = root["title"] as? String ?? ""
        let artist = (root["artist"] as? [String: Any])?["name"] as? String ?? (root["creator"] as? [String: Any])?["name"] as? String ?? ""
        let cover = root["cover_big"] as? String ?? root["picture_big"] as? String
        let list = ((root["tracks"] as? [String: Any])?["data"] as? [[String: Any]]) ?? []
        let tracks = list.map { var t = track($0, album: kind == "album" ? title : nil); if t.cover == nil { t.cover = cover }; return t }
        return MusicMeta(source: "Deezer", kind: kind, title: title, artist: artist, cover: cover, tracks: tracks)
    }

    // MARK: Універсальний резолвер за OpenGraph-тегами (Tidal, Яндекс Музика, Amazon Music…)
    static func openGraph(_ url: String, source: String) async throws -> MusicMeta {
        var html = ""
        var found: String? = nil
        var lastError: Error? = nil
        for ua in ogUserAgents {
            do {
                // identity: CDN Shazam кешує стиснений варіант лише як JS-оболонку без OpenGraph
                html = String(decoding: try await get(url, headers: ["Accept-Encoding": "identity"], userAgent: ua), as: UTF8.self)
                if let t = meta(html, "og:title") ?? meta(html, "twitter:title") { found = t; break }
            } catch { lastError = error }
        }
        guard var title = found else {
            if let lastError, found == nil, html.isEmpty { throw lastError }
            throw YTDLPError(message: L("Не вдалося визначити трек за посиланням."))
        }
        let desc = meta(html, "og:description") ?? ""
        let cover = meta(html, "og:image")
        // Типові форми: "Song - Artist", "Song by Artist", "Artist – Song | Service"
        title = title.components(separatedBy: " | ").first ?? title
        title = title.replacingOccurrences(of: " on Apple Music", with: "").replacingOccurrences(of: " - Apple Music", with: "")
        for suffix in [": Song Lyrics, Music Videos & Concerts", ": Song Lyrics", " Lyrics", " | Shazam", " - Shazam", " on TIDAL", " on Tidal", " | Genius"] {
            if let r = title.range(of: suffix, options: .caseInsensitive) { title = String(title[..<r.lowerBound]) }
        }
        var artist = ""
        if let r = title.range(of: " by ") { artist = String(title[r.upperBound...]); title = String(title[..<r.lowerBound]) }
        else if let r = title.range(of: " - ") ?? title.range(of: " – ") { artist = String(title[r.upperBound...]); title = String(title[..<r.lowerBound]) }
        else { artist = desc.components(separatedBy: " · ").first ?? "" }
        title = title.replacingOccurrences(of: "Song ", with: "").trimmingCharacters(in: .whitespaces)
        artist = artist.replacingOccurrences(of: "Song", with: "").trimmingCharacters(in: .whitespaces)
        let t = MusicTrack(id: url, title: title, artist: artist, album: nil, duration: nil, cover: cover)
        return MusicMeta(source: source, kind: "track", title: title, artist: artist, cover: cover, tracks: [t])
    }
}
