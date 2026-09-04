import SwiftUI

// Точка входу. `UniLoader --self-test` виконує вбудовані перевірки, `UniLoader --resolve <url>` показує,
// як музичне посилання (Spotify, Apple Music, Shazam, Deezer…) перетворюється на треки.
let args = CommandLine.arguments
if args.contains("--self-test") { exit(SelfTest.run()) }
if let i = args.firstIndex(of: "--resolve"), i + 1 < args.count {
    let url = args[i + 1]
    let sem = DispatchSemaphore(value: 0)
    Task {
        do {
            let m = try await MusicResolver.resolve(url)
            print("\(m.source) · \(m.kind) · \(m.title) — \(m.artist) · tracks: \(m.tracks.count) · cover: \(m.cover != nil)")
            for t in m.tracks.prefix(5) { print("  • \(t.display)  [\(Format.duration(t.duration))]  → \(t.searchURL)") }
        } catch { print("ERROR: \(error.localizedDescription)") }
        sem.signal()
    }
    sem.wait(); exit(0)
}
UniLoaderApp.main()
