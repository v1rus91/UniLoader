import SwiftUI
import UniformTypeIdentifiers

struct DownloadView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var urlFocused: Bool

    var body: some View {
        @Bindable var model = model
        @Bindable var prefs = model.prefs
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                urlRow
                if let svc = model.service {
                    HStack(spacing: 6) {
                        ServiceIcon(service: svc, size: 16)
                        Text(verbatim: model.musicSource ?? svc.name).foregroundStyle(svc.name == Service.generic.name ? Color.secondary : Color.accentColor)
                        if !svc.note.isEmpty { Text(verbatim: "·  \(svc.note)").foregroundStyle(.secondary) }
                    }.font(.callout).transition(.opacity)
                }
                if model.url.trimmingCharacters(in: .whitespaces).isEmpty {
                    dropZone
                } else {
                    if model.analyzing || model.info != nil || model.analyzeError != nil { preview }
                    if let info = model.info, !info.entries.isEmpty { entriesCard(info) }
                    options($prefs)
                    Button { model.download() } label: {
                        HStack { Text(downloadLabel).fontWeight(.semibold); Kbd(keys: "⌘↩") }.frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .glassButton(prominent: true).controlSize(.large)
                    if !model.statusText.isEmpty { Text(verbatim: model.statusText).font(.callout).foregroundStyle(.secondary) }
                }
            }
            .padding(24)
            .animation(.smooth(duration: 0.35), value: model.url.isEmpty)
            .animation(.smooth(duration: 0.35), value: model.analyzing)
        }
        .dropDestination(for: String.self) { items, _ in model.handleDrop(items) } isTargeted: { model.dropTargeted = $0 }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                HStack(spacing: 6) { Text("Вставити посилання").foregroundStyle(.secondary); Kbd(keys: "⌘V") }.font(.callout)
                Button { model.importFromFile() } label: { Label("Імпорт із файлу", systemImage: "doc.text") }.help("Імпортувати список посилань із текстового файлу (⌘O)")
                Button { model.newDownload() } label: { Label("Нове", systemImage: "plus") }.help("Нове завантаження (⌘N)")
            }
        }
        .onAppear { urlFocused = true }
        .onChange(of: model.focusURLTick) { _, _ in urlFocused = true }
        .onChange(of: model.url) { old, new in
            if new.count - old.count > 8 {
                let urls = extractURLs(new)
                if urls.count > 1 { model.addBatch(urls); model.newDownload(); return }
                if looksLikeURL(new), model.info?.url != new { model.analyze() }
            }
            if model.info != nil && model.info?.url != new.trimmingCharacters(in: .whitespaces) { model.info = nil }
        }
    }

    private var downloadLabel: String {
        if let info = model.info, info.entries.count > 1 {
            let n = model.selectedEntries.count
            return n == info.entries.count ? String(format: L("Завантажити всі (%d)"), n) : String(format: L("Завантажити вибрані (%d)"), n)
        }
        return L("Завантажити")
    }

    private var urlRow: some View {
        @Bindable var model = model
        return HStack(spacing: 8) {
            TextField("https://…  посилання на відео, трек, допис або плейлист (можна кілька)", text: $model.url)
                .textFieldStyle(.roundedBorder).controlSize(.large).focused($urlFocused).onSubmit { model.analyze() }
            Button("Вставити") { model.pasteAndAnalyze() }.glassButton().controlSize(.large)
            Button { model.analyze() } label: {
                HStack(spacing: 6) {
                    if model.analyzing { ProgressView().controlSize(.small) }
                    Text(model.analyzing ? "Аналіз…" : "Аналізувати"); Kbd(keys: "↩")
                }
            }.glassButton(prominent: true).controlSize(.large).disabled(model.analyzing)
        }
    }

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc").font(.system(size: 34, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 76, height: 76).glassCard(20)
            Text("Вставте посилання").font(.title3.weight(.semibold)).padding(.top, 8)
            HStack(spacing: 6) { Text("натисніть").foregroundStyle(.secondary); Kbd(keys: "⌘V") }
            Text("або перетягніть посилання з браузера прямо сюди · кілька посилань підуть у чергу одразу").font(.callout).foregroundStyle(.tertiary)
            Text("YouTube · Instagram · TikTok · X · Facebook · Reddit · Twitch · SoundCloud · Spotify · Apple Music · Shazam · ще 1000+")
                .font(.caption).foregroundStyle(.tertiary).padding(.top, 14)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 56)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(model.dropTargeted ? Color.accentColor : Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [8, 6])))
        .background(model.dropTargeted ? Color.accentColor.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: model.dropTargeted)
        .padding(.top, 20)
    }

    private var preview: some View {
        HStack(alignment: .top, spacing: 16) {
            Thumb(url: model.info?.thumbnail, placeholder: model.analyzing ? "⏳" : (model.analyzeError != nil ? "⚠️" : "🎬"), service: model.info == nil ? nil : model.service)
            VStack(alignment: .leading, spacing: 6) {
                if model.analyzing {
                    Text(verbatim: Format.truncate(model.url, 90)).font(.title3.weight(.semibold))
                    Text(model.musicSource != nil ? "Шукаю трек…" : "Зачекайте…").foregroundStyle(.secondary)
                } else if let err = model.analyzeError {
                    Text("Не вдалося отримати інформацію").font(.title3.weight(.semibold))
                    Text(verbatim: err).foregroundStyle(.secondary)
                } else if let i = model.info {
                    Text(verbatim: i.title).font(.title3.weight(.semibold)).lineLimit(3)
                    HStack(spacing: 12) {
                        if let m = i.music {
                            Label(m.kind == "track" ? L("Трек") : (m.kind == "album" ? L("Альбом") : L("Плейлист")) + (i.count > 1 ? " · \(i.count)" : ""), systemImage: "music.note")
                        } else {
                            Label(i.isPlaylist ? String(format: L("Плейлист · %d елементів"), i.count) : i.durationText, systemImage: i.isPlaylist ? "list.and.film" : "clock")
                        }
                        if !i.uploader.isEmpty { Label(i.uploader, systemImage: "person") }
                        if let ex = i.extractor { Text(verbatim: ex) }
                    }.font(.callout).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        if let v = i.viewCount { Text(verbatim: "\(Format.count(v)) \(L("переглядів"))") }
                        if let l = i.likeCount { Label(Format.count(l), systemImage: "heart") }
                        if let d = i.dateText { Text(verbatim: d) }
                        if i.formatsCount > 0 { Text(verbatim: "\(i.formatsCount) \(L("форматів"))") }
                        if i.music != nil, let dur = i.duration { Label(Format.duration(dur), systemImage: "clock") }
                    }.font(.callout).foregroundStyle(.secondary)
                    if !i.description.isEmpty { Text(verbatim: Format.truncate(i.description, 200)).font(.callout).foregroundStyle(.tertiary).lineLimit(3) }
                    HStack {
                        Button { if let u = URL(string: model.url) { NSWorkspace.shared.open(u) } } label: { Label("Відкрити в браузері", systemImage: "arrow.up.right") }
                        Button { SystemActions.copy(i.title); model.manager.showToast(L("Скопійовано"), .info, seconds: 1.2) } label: { Label("Копіювати назву", systemImage: "doc.on.doc") }
                    }.glassButton().controlSize(.small).padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14).glassCard()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// Елементи плейлиста / треки з чекбоксами
    private func entriesCard(_ info: MediaInfo) -> some View {
        @Bindable var model = model
        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Button("Усі") { model.selectedEntries = Set(info.entries.map(\.id)) }
                    Button("Жодного") { model.selectedEntries = [] }
                }.glassButton().controlSize(.small).padding(.bottom, 4)
                ForEach(Array(info.entries.enumerated()), id: \.element.id) { i, e in
                    Toggle(isOn: Binding(get: { model.selectedEntries.contains(e.id) },
                                         set: { on in if on { model.selectedEntries.insert(e.id) } else { model.selectedEntries.remove(e.id) } })) {
                        HStack {
                            Text(verbatim: "\(i + 1).").foregroundStyle(.tertiary).frame(width: 34, alignment: .trailing)
                            Text(verbatim: e.title).lineLimit(1)
                            Spacer()
                            if let d = e.duration { Text(verbatim: Format.duration(d)).foregroundStyle(.secondary).monospacedDigit() }
                        }
                    }.toggleStyle(.checkbox)
                }
            }.padding(.top, 6)
        } label: {
            HStack {
                Text(info.music != nil ? "Треки" : "Елементи плейлиста").font(.headline)
                Text(verbatim: "\(model.selectedEntries.count) / \(info.entries.count)").foregroundStyle(.secondary)
            }
        }
        .padding(14).glassCard()
    }

    private func options(_ prefs: Bindable<Prefs>) -> some View {
        @Bindable var model = model
        let isMusic = model.musicSource != nil
        let videoFormats = (model.info?.formats ?? []).filter { $0.hasVideo }.sorted { ($0.height ?? 0, $0.tbr ?? 0) > ($1.height ?? 0, $1.tbr ?? 0) }
        let audioFormats = (model.info?.formats ?? []).filter { !$0.hasVideo && $0.hasAudio }.sorted { ($0.tbr ?? 0) > ($1.tbr ?? 0) }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Параметри").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                GridRow {
                    Text("Тип").foregroundStyle(.secondary)
                    Picker("", selection: prefs.mode) { ForEach(Mode.allCases) { Text($0.label).tag($0) } }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 180).disabled(isMusic)
                    Text("Якість відео").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                    Picker("", selection: prefs.quality) { ForEach(Quality.allCases) { Text($0.label).tag($0) } }
                        .labelsHidden().frame(width: 170).disabled(model.prefs.mode == .audio || isMusic || model.selectedFormat != nil)
                }
                GridRow {
                    Text("").gridCellUnsizedAxes(.horizontal)
                    HStack(spacing: 14) {
                        Toggle("Увесь плейлист", isOn: prefs.playlist).disabled(isMusic)
                        Toggle("Субтитри", isOn: prefs.subtitles).disabled(isMusic)
                        Toggle("Обкладинка", isOn: prefs.embedThumbnail)
                    }.toggleStyle(.checkbox).fixedSize()
                    Text("Формат аудіо").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                    Picker("", selection: prefs.audioFormat) { ForEach(AudioFormat.allCases) { Text(verbatim: $0.rawValue).tag($0) } }
                        .labelsHidden().frame(width: 170).disabled(model.prefs.mode == .video && !isMusic)
                }
                if !isMusic && (!videoFormats.isEmpty || !audioFormats.isEmpty) {
                    GridRow {
                        Text("Точний формат").foregroundStyle(.secondary)
                        Picker("", selection: $model.selectedFormat) {
                            Text("Авто (за якістю)").tag(String?.none)
                            if model.prefs.mode == .video {
                                ForEach(videoFormats) { f in Text(verbatim: f.label).tag(String?.some(f.id)) }
                            } else {
                                ForEach(audioFormats) { f in Text(verbatim: f.label).tag(String?.some(f.id)) }
                            }
                        }.labelsHidden().frame(maxWidth: 520, alignment: .leading).gridCellColumns(3)
                    }
                }
                GridRow {
                    Text("Зберегти в").foregroundStyle(.secondary)
                    HStack {
                        TextField("", text: prefs.downloadDir).textFieldStyle(.roundedBorder)
                        Button("Обрати…") { if let d = SystemActions.chooseFolder(initial: model.prefs.downloadDir) { model.prefs.downloadDir = d } }.glassButton()
                    }.gridCellColumns(3)
                }
            }
            DisclosureGroup(isExpanded: $model.showAdvanced) {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    GridRow {
                        Text("Фрагмент").foregroundStyle(.secondary)
                        TextField("00:01:00-00:02:30", text: prefs.sections).textFieldStyle(.roundedBorder).frame(width: 180)
                        Text("Ліміт швидкості").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                        TextField("2M", text: prefs.rateLimit).textFieldStyle(.roundedBorder).frame(width: 100)
                    }
                    GridRow {
                        Text("").gridCellUnsizedAxes(.horizontal)
                        HStack(spacing: 14) {
                            Toggle("Вирізати спонсорські вставки (SponsorBlock)", isOn: prefs.sponsorBlock)
                            Toggle("Поділити на розділи", isOn: prefs.splitChapters)
                        }.toggleStyle(.checkbox).fixedSize().gridCellColumns(3)
                    }
                    GridRow {
                        Text("Аргументи yt-dlp").foregroundStyle(.secondary)
                        TextField("--write-thumbnail --no-mtime", text: prefs.extraArgs).textFieldStyle(.roundedBorder).gridCellColumns(3)
                    }
                }.padding(.top, 8)
            } label: {
                Text("Додатково").font(.subheadline.weight(.medium))
            }
        }
        .padding(14).glassCard()
    }
}
