import SwiftUI

struct QueueView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            if model.manager.tasks.isEmpty {
                EmptyState(symbol: "list.bullet", title: L("Черга порожня"), subtitle: L("Додайте посилання в розділі «Завантажити»"),
                           action: { model.newDownload() }, actionLabel: L("Нове завантаження  ⌘N"))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(model.manager.tasks) { task in
                        TaskRow(task: task).transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }.padding(20)
            }
        }
        .animation(.smooth, value: model.manager.tasks.map(\.id))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { model.manager.clearFinished() } label: { Label("Очистити завершені", systemImage: "trash") }
                Button(role: .destructive) { model.manager.cancelAll() } label: { Label("Скасувати всі", systemImage: "stop.circle") }
                    .disabled(model.manager.activeCount == 0)
            }
        }
    }
}

struct TaskRow: View {
    @Environment(AppModel.self) private var model
    let task: DownloadTask
    @State private var showLog = false

    private var color: Color {
        switch task.status {
        case .done: return .green
        case .error: return .red
        case .processing: return .orange
        case .queued, .cancelled: return .secondary
        default: return .accentColor
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Thumb(url: task.thumbnail, placeholder: "🎬", service: task.service, size: CGSize(width: 112, height: 63), radius: 6)
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: Format.truncate(task.title, 95)).font(.headline).lineLimit(1)
                HStack(spacing: 5) {
                    ServiceIcon(service: task.service, size: 14)
                    Text(verbatim: "\(task.music?.artist.isEmpty == false ? task.music!.artist : (task.service?.name ?? ""))   ·   \(task.modeLabel)   ·   \(Format.truncate(task.url, 60))").lineLimit(1)
                }.font(.callout).foregroundStyle(.secondary)
                if task.status == .fetching || task.status == .processing {
                    ProgressView().progressViewStyle(.linear).tint(color)
                } else {
                    ProgressView(value: task.status == .queued ? 0 : task.progress).tint(color).animation(.smooth(duration: 0.4), value: task.progress)
                }
                Text(verbatim: task.detail.isEmpty ? task.status.label : "\(task.status.label)  ·  \(task.detail)").font(.callout).foregroundStyle(color).lineLimit(2)
            }
            VStack(spacing: 6) {
                if task.status.isActive {
                    Button(role: .destructive) { model.manager.cancel(task) } label: { Text("Скасувати").frame(width: 120) }
                }
                Button { SystemActions.reveal(task.filename.isEmpty ? task.options.outputDir : task.filename) } label: { Text("Показати у Finder").frame(width: 120) }
                if task.status == .error || task.status == .cancelled {
                    Button { model.manager.retry(task) } label: { Label("Повторити", systemImage: "arrow.clockwise").frame(width: 120) }
                }
                Button { showLog = true } label: { Label("Лог", systemImage: "doc.plaintext").frame(width: 120) }
                if !task.status.isActive {
                    Button { model.manager.remove(task) } label: { Text("Прибрати").frame(width: 120) }
                }
            }
            .glassButton().controlSize(.small)
        }
        .padding(12).glassCard()
        .animation(.smooth, value: task.status)
        .sheet(isPresented: $showLog) { LogSheet(task: task) }
    }
}
