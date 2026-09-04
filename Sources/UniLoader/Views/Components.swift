import SwiftUI

// MARK: - Liquid Glass з фолбеком на матеріал (macOS < 26)

struct GlassCard: ViewModifier {
    var radius: CGFloat = 14
    var tint: Color? = nil
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular, in: .rect(cornerRadius: radius))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(.white.opacity(0.08)))
        }
    }
}

extension View {
    func glassCard(_ radius: CGFloat = 14, tint: Color? = nil) -> some View { modifier(GlassCard(radius: radius, tint: tint)) }

    @ViewBuilder func glassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        } else {
            if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
        }
    }

    @ViewBuilder func glassWindowBackground() -> some View {
        if #available(macOS 15.0, *) { containerBackground(.thinMaterial, for: .window) } else { self }
    }
}

// MARK: - Логотипи сервісів (Simple Icons SVG як template + favicon PNG)

final class IconStore {
    static let shared = IconStore()
    /// Одноколірні PNG-логотипи, які тонуються як шаблон (чорний word-mark невидимий у темній темі)
    static let monochromePNGs: Set<String> = ["vevo"]
    private var cache: [String: (NSImage, Bool)] = [:]
    private let dirs: [URL] = {
        var d: [URL] = []
        if let r = Bundle.main.resourceURL { d.append(r.appendingPathComponent("icons")) }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        d.append(root.appendingPathComponent("Resources/icons"))
        return d
    }()

    func image(for slug: String) -> (NSImage, Bool)? {
        guard !slug.isEmpty else { return nil }
        if let c = cache[slug] { return c }
        for dir in dirs {
            for (ext, isSVG) in [("svg", true), ("png", false)] {
                let url = dir.appendingPathComponent("\(slug).\(ext)")
                if let img = NSImage(contentsOf: url) {
                    let template = isSVG || IconStore.monochromePNGs.contains(slug)
                    img.isTemplate = template
                    cache[slug] = (img, template)
                    return (img, template)
                }
            }
        }
        return nil
    }
}

struct ServiceIcon: View {
    let service: Service?
    var size: CGFloat = 18
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let service, let (img, template) = IconStore.shared.image(for: service.slug) {
            if template {
                Image(nsImage: img).resizable().renderingMode(.template)
                    .foregroundStyle(tint(service.color))
                    .frame(width: size, height: size)
            } else {
                Image(nsImage: img).resizable().interpolation(.high).scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            }
        } else {
            Text(service?.icon ?? "🌐").font(.system(size: size * 0.85)).frame(width: size, height: size)
        }
    }

    private func tint(_ hex: String) -> Color {
        let c = Color(hex: hex)
        let n = NSColor(c).usingColorSpace(.sRGB) ?? .black
        let lum = 0.2126 * n.redComponent + 0.7152 * n.greenComponent + 0.0722 * n.blueComponent
        if scheme == .dark && lum < 0.2 { return .primary }
        if scheme == .light && lum > 0.85 { return .primary }
        return c
    }
}

// MARK: - Дрібні елементи

struct Kbd: View {
    let keys: String
    var body: some View {
        Text(verbatim: keys)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct SectionHeader: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
    }
}

struct Thumb: View {
    let url: String?
    let placeholder: String
    var service: Service? = nil
    var size: CGSize = CGSize(width: 288, height: 162)
    var radius: CGFloat = 8

    @ViewBuilder private var fallback: some View {
        if service != nil { ServiceIcon(service: service, size: size.height * 0.45) }
        else { Text(verbatim: placeholder).font(.system(size: size.height / 3)) }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.quaternary)
            if let url, let u = URL(string: url) {
                AsyncImage(url: u, transaction: Transaction(animation: .easeOut(duration: 0.35))) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill().transition(.opacity)
                    case .failure: fallback
                    default: ProgressView().controlSize(.small)
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil
    var actionLabel: String = ""
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 34, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 76, height: 76).glassCard(20)
            Text(verbatim: title).font(.title3.weight(.semibold)).padding(.top, 6)
            Text(verbatim: subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let action {
                Button(action: action) { Text(verbatim: actionLabel) }.glassButton(prominent: true).padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}

struct ToastView: View {
    let toast: Toast
    var symbol: String {
        switch toast.kind {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
    var color: Color {
        switch toast.kind {
        case .success: return .green
        case .info: return .accentColor
        case .warning: return .orange
        case .error: return .red
        }
    }
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(verbatim: toast.text).lineLimit(2)
            if let label = toast.actionLabel, let action = toast.action {
                Button(action: action) { Text(verbatim: label).fontWeight(.semibold) }.glassButton(prominent: true).controlSize(.small)
            }
        }
        .font(.callout)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .glassCard(999)
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .padding(.bottom, 18)
    }
}

// MARK: - Лог завдання

struct LogSheet: View {
    let task: DownloadTask
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(verbatim: Format.truncate(task.title, 70)).font(.headline)
                Spacer()
                Button { SystemActions.copy(task.log.joined(separator: "\n")) } label: { Label("Скопіювати лог", systemImage: "doc.on.doc") }.glassButton()
                Button("Закрити") { dismiss() }.keyboardShortcut(.cancelAction).glassButton()
            }
            ScrollView {
                Text(verbatim: task.log.isEmpty ? L("Лог порожній") : task.log.joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(20).frame(width: 720, height: 460)
    }
}

// MARK: - Шпаргалка та онбординг

let shortcutList: [(String, String)] = [
    ("⌘V", "Вставити посилання з буфера й проаналізувати"),
    ("↩", "Аналізувати посилання"),
    ("⌘↩", "Завантажити"),
    ("⌘N", "Нове завантаження"),
    ("⌘O", "Імпортувати посилання з файлу"),
    ("⌘L", "Перейти до поля посилання"),
    ("⌘F", "Пошук на поточній сторінці"),
    ("⌘1 … ⌘5", "Перемкнути розділ"),
    ("⌘⇧D", "Швидка панель (глобально, з будь-якої програми)"),
    ("⌘,", "Налаштування"),
    ("⌘/", "Ця шпаргалка"),
    ("Esc", "Закрити панель"),
]

struct ShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Клавіатурні шорткати").font(.title2.weight(.bold))
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                ForEach(shortcutList, id: \.0) { k, v in
                    GridRow { Kbd(keys: k).gridColumnAlignment(.trailing); Text(LocalizedStringKey(v)) }
                }
            }
            HStack { Spacer(); Button("Готово") { dismiss() }.keyboardShortcut(.defaultAction).glassButton(prominent: true) }
        }
        .padding(28).frame(width: 480)
    }
}

struct OnboardingSheet: View {
    @Environment(AppModel.self) private var model
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill").font(.system(size: 52)).foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeating, isActive: true)
            Text("Ласкаво просимо в UniLoader").font(.title2.weight(.bold))
            Text("Скопіюйте посилання на відео чи трек у будь-якому браузері,\nповерніться сюди й просто натисніть")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Kbd(keys: "⌘V").font(.title3.weight(.bold)).scaleEffect(pulse ? 1.06 : 1)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            Text("Або взагалі нічого не натискайте: застосунок сам помітить скопійоване посилання і запропонує завантажити.")
                .font(.callout).foregroundStyle(.tertiary).multilineTextAlignment(.center)
            HStack {
                Button("Шорткати  ⌘/") { model.showOnboarding = false; model.showShortcuts = true }.glassButton()
                Button("Почати") { model.showOnboarding = false }.keyboardShortcut(.defaultAction).glassButton(prominent: true)
            }.padding(.top, 8)
        }
        .padding(32).frame(width: 460)
        .onAppear { pulse = true }
        .onDisappear { model.prefs.onboarded = true }
    }
}
