import Foundation

/// Каталог популярних сервісів для інтерфейсу. Реальне завантаження виконує yt-dlp (1000+ сайтів).
struct Service: Identifiable, Hashable {
    let name: String
    let icon: String
    let domains: [String]
    let category: String
    let color: String
    var note: String = ""
    var id: String { name }
    /// Імʼя файлу логотипа в Resources/icons (SVG із Simple Icons або favicon PNG)
    var slug: String { Service.slugs[name] ?? "" }

    static let slugs: [String: String] = [
        "YouTube Music": "youtubemusic", "YouTube": "youtube", "Vimeo": "vimeo", "Dailymotion": "dailymotion", "Rumble": "rumble",
        "Odysee": "odysee", "Bilibili": "bilibili", "Niconico": "niconico", "Streamable": "streamable", "Coub": "coub", "9GAG": "9gag",
        "Imgur": "imgur", "Loom": "loom", "Rutube": "rutube", "BitChute": "bitchute", "Vevo": "vevo", "Instagram": "instagram",
        "TikTok": "tiktok", "Facebook": "facebook", "X (Twitter)": "x", "Threads": "threads", "Reddit": "reddit", "Pinterest": "pinterest",
        "Snapchat": "snapchat", "LinkedIn": "linkedin", "Tumblr": "tumblr", "Bluesky": "bluesky", "Telegram": "telegram", "VK Video": "vk",
        "OK.ru": "odnoklassniki", "Likee": "likee", "Douyin": "douyin", "Xiaohongshu": "xiaohongshu", "Weibo": "sinaweibo", "Twitch": "twitch",
        "Kick": "kick", "Trovo": "trovo", "SoundCloud": "soundcloud", "Bandcamp": "bandcamp", "Mixcloud": "mixcloud", "Audiomack": "audiomack",
        "Apple Podcasts": "applepodcasts", "Audius": "audius", "TED": "ted", "Khan Academy": "khanacademy", "Archive.org": "internetarchive",
        "Google Drive": "googledrive", "Spotify": "spotify", "Apple Music": "applemusic", "Shazam": "shazam", "Deezer": "deezer", "Tidal": "tidal", "Amazon Music": "amazonmusic", "Яндекс Музика": "yandexmusic", "Музичні сервіси": "spotify", "Dropbox": "dropbox", "Patreon": "patreon", "Boosty": "boosty", "Steam": "steam", "BBC": "bbc", "CNN": "cnn",
    ]

    static func named(_ name: String) -> Service? { all.first { $0.name == name } }

    static let categories = ["Відео", "Соцмережі", "Стріми", "Музика", "Освіта", "Новини", "Інше"]

    // Порядок важливий: специфічніші домени (music.youtube.com) раніше.
    static let all: [Service] = [
        Service(name: "YouTube Music", icon: "🎵", domains: ["music.youtube.com"], category: "Музика", color: "#FF0033"),
        Service(name: "YouTube", icon: "▶️", domains: ["youtube.com", "youtu.be", "youtube-nocookie.com"], category: "Відео", color: "#FF0000", note: "Відео, Shorts, плейлисти, канали, прямі ефіри"),
        Service(name: "Vimeo", icon: "🎥", domains: ["vimeo.com"], category: "Відео", color: "#1AB7EA"),
        Service(name: "Dailymotion", icon: "🎞️", domains: ["dailymotion.com", "dai.ly"], category: "Відео", color: "#0066DC"),
        Service(name: "Rumble", icon: "🟩", domains: ["rumble.com"], category: "Відео", color: "#85C742"),
        Service(name: "Odysee", icon: "🌊", domains: ["odysee.com"], category: "Відео", color: "#EF1970"),
        Service(name: "Bilibili", icon: "📺", domains: ["bilibili.com", "b23.tv"], category: "Відео", color: "#00A1D6"),
        Service(name: "Niconico", icon: "🇯🇵", domains: ["nicovideo.jp", "nico.ms"], category: "Відео", color: "#252525"),
        Service(name: "Streamable", icon: "⏯️", domains: ["streamable.com"], category: "Відео", color: "#0F90FA"),
        Service(name: "Coub", icon: "🔁", domains: ["coub.com"], category: "Відео", color: "#0332FF"),
        Service(name: "9GAG", icon: "😂", domains: ["9gag.com"], category: "Відео", color: "#000000"),
        Service(name: "Imgur", icon: "🖼️", domains: ["imgur.com"], category: "Відео", color: "#1BB76E"),
        Service(name: "Loom", icon: "🔴", domains: ["loom.com"], category: "Відео", color: "#625DF5"),
        Service(name: "Rutube", icon: "🅁", domains: ["rutube.ru"], category: "Відео", color: "#100943"),
        Service(name: "BitChute", icon: "🔺", domains: ["bitchute.com"], category: "Відео", color: "#EF4137"),
        Service(name: "Vevo", icon: "🎼", domains: ["vevo.com"], category: "Відео", color: "#000000"),
        Service(name: "Instagram", icon: "📸", domains: ["instagram.com", "instagr.am"], category: "Соцмережі", color: "#E1306C", note: "Reels, дописи, каруселі, stories (потрібні cookies)"),
        Service(name: "TikTok", icon: "🎶", domains: ["tiktok.com", "vm.tiktok.com", "vt.tiktok.com"], category: "Соцмережі", color: "#69C9D0", note: "Відео без водяного знака, звук, слайдшоу"),
        Service(name: "Facebook", icon: "📘", domains: ["facebook.com", "fb.watch", "fb.com"], category: "Соцмережі", color: "#1877F2"),
        Service(name: "X (Twitter)", icon: "🐦", domains: ["twitter.com", "x.com", "t.co"], category: "Соцмережі", color: "#1DA1F2"),
        Service(name: "Threads", icon: "🧵", domains: ["threads.net", "threads.com"], category: "Соцмережі", color: "#000000"),
        Service(name: "Reddit", icon: "👽", domains: ["reddit.com", "redd.it"], category: "Соцмережі", color: "#FF4500"),
        Service(name: "Pinterest", icon: "📌", domains: ["pinterest.com", "pin.it"], category: "Соцмережі", color: "#E60023"),
        Service(name: "Snapchat", icon: "👻", domains: ["snapchat.com"], category: "Соцмережі", color: "#FFFC00"),
        Service(name: "LinkedIn", icon: "💼", domains: ["linkedin.com"], category: "Соцмережі", color: "#0A66C2"),
        Service(name: "Tumblr", icon: "📝", domains: ["tumblr.com"], category: "Соцмережі", color: "#001935"),
        Service(name: "Bluesky", icon: "🦋", domains: ["bsky.app"], category: "Соцмережі", color: "#0085FF"),
        Service(name: "Telegram", icon: "✈️", domains: ["t.me", "telegram.me"], category: "Соцмережі", color: "#26A5E4", note: "Публічні канали (t.me/канал/номер)"),
        Service(name: "VK Video", icon: "🔵", domains: ["vk.com", "vkvideo.ru", "vk.ru"], category: "Соцмережі", color: "#0077FF"),
        Service(name: "OK.ru", icon: "🟠", domains: ["ok.ru", "odnoklassniki.ru"], category: "Соцмережі", color: "#EE8208"),
        Service(name: "Likee", icon: "💛", domains: ["likee.video", "likee.com"], category: "Соцмережі", color: "#FFD400"),
        Service(name: "Douyin", icon: "🎵", domains: ["douyin.com"], category: "Соцмережі", color: "#000000"),
        Service(name: "Xiaohongshu", icon: "📕", domains: ["xiaohongshu.com", "xhslink.com"], category: "Соцмережі", color: "#FF2442"),
        Service(name: "Weibo", icon: "🈷️", domains: ["weibo.com", "weibo.cn"], category: "Соцмережі", color: "#E6162D"),
        Service(name: "Twitch", icon: "🟣", domains: ["twitch.tv"], category: "Стріми", color: "#9146FF", note: "VOD, кліпи, поточні трансляції"),
        Service(name: "Kick", icon: "🟢", domains: ["kick.com"], category: "Стріми", color: "#53FC18"),
        Service(name: "Trovo", icon: "🎮", domains: ["trovo.live"], category: "Стріми", color: "#19D66B"),
        Service(name: "SoundCloud", icon: "☁️", domains: ["soundcloud.com", "snd.sc"], category: "Музика", color: "#FF5500"),
        Service(name: "Bandcamp", icon: "🎸", domains: ["bandcamp.com"], category: "Музика", color: "#1DA0C3"),
        Service(name: "Mixcloud", icon: "🎧", domains: ["mixcloud.com"], category: "Музика", color: "#5000FF"),
        Service(name: "Audiomack", icon: "🎤", domains: ["audiomack.com"], category: "Музика", color: "#FFA200"),
        Service(name: "Apple Podcasts", icon: "🎙️", domains: ["podcasts.apple.com"], category: "Музика", color: "#B150E2"),
        Service(name: "Audius", icon: "🎚️", domains: ["audius.co"], category: "Музика", color: "#CC0FE0"),
        Service(name: "Spotify", icon: "🟢", domains: ["open.spotify.com", "spotify.com", "spotify.link"], category: "Музика", color: "#1DB954", note: "Трек, альбом, плейлист → пошук на YouTube, аудіо з тегами"),
        Service(name: "Apple Music", icon: "🍎", domains: ["music.apple.com", "itunes.apple.com"], category: "Музика", color: "#FA243C", note: "Пісня, альбом, плейлист → пошук на YouTube, аудіо з тегами"),
        Service(name: "Shazam", icon: "🔷", domains: ["shazam.com"], category: "Музика", color: "#0088FF", note: "Розпізнаний трек → пошук на YouTube"),
        Service(name: "Deezer", icon: "🟣", domains: ["deezer.com", "deezer.page.link"], category: "Музика", color: "#A238FF", note: "Трек, альбом, плейлист → пошук на YouTube"),
        Service(name: "Tidal", icon: "⬛", domains: ["tidal.com", "listen.tidal.com"], category: "Музика", color: "#000000", note: "Трек → пошук на YouTube"),
        Service(name: "Amazon Music", icon: "🎵", domains: ["music.amazon.com"], category: "Музика", color: "#25D1DA", note: "Трек → пошук на YouTube"),
        Service(name: "Яндекс Музика", icon: "🟡", domains: ["music.yandex.ru", "music.yandex.com"], category: "Музика", color: "#FFCC00", note: "Трек → пошук на YouTube"),
        Service(name: "Музичні сервіси", icon: "🎼", domains: [], category: "Музика", color: "#FF2D55", note: "Spotify, Apple Music, Shazam, Deezer, Tidal…"),
        Service(name: "TED", icon: "🔴", domains: ["ted.com"], category: "Освіта", color: "#E62B1E"),
        Service(name: "Khan Academy", icon: "🎓", domains: ["khanacademy.org"], category: "Освіта", color: "#14BF96"),
        Service(name: "Archive.org", icon: "📚", domains: ["archive.org"], category: "Інше", color: "#428BCA"),
        Service(name: "Google Drive", icon: "📁", domains: ["drive.google.com"], category: "Інше", color: "#34A853", note: "Файли з публічним доступом"),
        Service(name: "Dropbox", icon: "📦", domains: ["dropbox.com"], category: "Інше", color: "#0061FF"),
        Service(name: "Patreon", icon: "🧡", domains: ["patreon.com"], category: "Інше", color: "#FF424D", note: "Потрібні cookies"),
        Service(name: "Boosty", icon: "🟧", domains: ["boosty.to"], category: "Інше", color: "#F15F2C"),
        Service(name: "Steam", icon: "🎮", domains: ["store.steampowered.com", "steamcommunity.com"], category: "Інше", color: "#171A21", note: "Трейлери ігор"),
        Service(name: "BBC", icon: "📰", domains: ["bbc.co.uk", "bbc.com"], category: "Новини", color: "#BB1919"),
        Service(name: "CNN", icon: "📰", domains: ["cnn.com"], category: "Новини", color: "#CC0000"),
    ]

    static let generic = Service(name: "Інший сайт", icon: "🌐", domains: [], category: "Інше", color: "#607D8B",
                                 note: "yt-dlp спробує знайти медіа на сторінці")

    static func detect(_ raw: String) -> Service? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") { s = "https://" + s }
        guard var host = URL(string: s)?.host?.lowercased(), host.contains(".") else { return nil }
        for p in ["www.", "m.", "mobile.", "web."] where host.hasPrefix(p) { host.removeFirst(p.count) }
        for svc in all {
            for d in svc.domains where host == d || host.hasSuffix("." + d) { return svc }
        }
        return generic
    }

    static func grouped() -> [(String, [Service])] {
        categories.compactMap { c in
            let items = all.filter { $0.category == c && !$0.domains.isEmpty }
            return items.isEmpty ? nil : (c, items)
        }
    }
}
