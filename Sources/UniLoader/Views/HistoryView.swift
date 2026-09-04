import SwiftUI
import QuickLook

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var previewURL: URL?

    private var items: [HistoryItem] {
        let q = query.lowercased()
        return model.manager.history.filter { q.isEmpty || ($0.title + $0.serviceName + $0.uploader).lowercased().contains(q) }
    }

    var body: some View {
        ScrollView {
            if items.isEmpty {
                EmptyState(symbol: "clock", title: query.isEmpty ? L("Історія порожня") : L("Нічого не знайдено"),
                           subtitle: query.isEmpty ? L("Завершені завантаження зʼявляться тут") : String(format: L("За запитом «%@»"), query))
            } else {
                LazyVStack(spacing: 8) { ForEach(items) { item in row(item) } }.padding(20)
            }
        }
        .quickLookPreview($previewURL)
        .searchable(text: $query, placement: .toolbar, prompt: "Пошук")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) { model.manager.clearHistory() } label: { Label("Очистити історію", systemImage: "trash") }
                    .disabled(model.manager.history.isEmpty)
            }
        }
    }

    private func row(_ item: HistoryItem) -> some View {
        let exists = !item.filename.isEmpty && FileManager.default.fileExists(atPath: item.filename)
        return HStack(spacing: 12) {
            Thumb(url: item.thumbnail, placeholder: item.serviceIcon, service: Service.named(item.serviceName), size: CGSize(width: 96, height: 54), radius: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: Format.truncate(item.title, 95)).font(.headline).lineLimit(1)
                HStack(spacing: 10) {
                    HStack(spacing: 5) { ServiceIcon(service: Service.named(item.serviceName), size: 14); Text(verbatim: item.serviceName) }
                    if let d = item.duration { Label(Format.duration(d), systemImage: "clock") }
                    Text(verbatim: item.mode)
                    Text(verbatim: Format.dateTime.string(from: item.finishedAt))
                    if !exists { Text("файл переміщено або видалено").foregroundStyle(.orange) }
                }.font(.callout).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            HStack(spacing: 6) {
                Button { previewURL = URL(fileURLWithPath: item.filename) } label: { Image(systemName: "eye") }.glassButton().disabled(!exists).help("Швидкий перегляд")
                Button("Відкрити") { if !SystemActions.open(item.filename) { model.manager.showToast(L("Файл не знайдено"), .warning) } }.glassButton(prominent: true).disabled(!exists)
                Button("Finder") { SystemActions.reveal(item.filename.isEmpty ? item.outputDir : item.filename) }.glassButton()
                Button { model.setURL(item.url, analyze: false) } label: { Image(systemName: "arrow.up.right") }.glassButton().help("Використати посилання знову")
            }.controlSize(.small)
        }
        .padding(10).glassCard(12)
        .onDrag { exists ? NSItemProvider(contentsOf: URL(fileURLWithPath: item.filename)) ?? NSItemProvider() : NSItemProvider() }
        .help(exists ? "Перетягніть у Finder або іншу програму" : "")
    }
}
