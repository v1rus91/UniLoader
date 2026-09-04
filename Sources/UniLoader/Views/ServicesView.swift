import SwiftUI

struct ServicesView: View {
    @State private var query = ""
    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(Service.all.count) популярних сервісів у каталозі та понад 1000 сайтів через yt-dlp. Вставте посилання — сервіс визначиться автоматично.")
                    .foregroundStyle(.secondary)
                let q = query.lowercased()
                let groups = Service.grouped().compactMap { (cat, items) -> (String, [Service])? in
                    let f = items.filter { q.isEmpty || $0.name.lowercased().contains(q) || $0.domains.contains { $0.contains(q) } }
                    return f.isEmpty ? nil : (cat, f)
                }
                if groups.isEmpty {
                    EmptyState(symbol: "magnifyingglass", title: "Нічого не знайдено", subtitle: "За запитом «\(query)»")
                }
                ForEach(groups, id: \.0) { cat, items in
                    SectionHeader(text: cat)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(items) { s in chip(s) }
                    }
                }
                Text("Не бачите свого сайту? Повний перелік: github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md")
                    .font(.callout).foregroundStyle(.secondary).padding(.top, 8)
            }
            .padding(24)
        }
        .searchable(text: $query, placement: .toolbar, prompt: "Пошук сервісу")
    }

    private func chip(_ s: Service) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) { ServiceIcon(service: s, size: 22); Text(s.name).font(.headline) }
            Text(s.domains.first ?? "").font(.caption).foregroundStyle(.secondary)
            Text(s.note.isEmpty ? " " : s.note).font(.caption).foregroundStyle(.tertiary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12).glassCard(12, tint: Color(hex: s.color).opacity(0.12))
    }
}

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
