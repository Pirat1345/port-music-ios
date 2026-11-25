import SwiftUI

// MARK: - Library Category Configuration (Mirrors Web LibraryPage DEFAULT_CATEGORY_ORDER)
struct LibraryCategoryConfig: Identifiable, Codable, Equatable {
    let id: String
    let label: String
    let iconName: String
    var visible: Bool
}

// MARK: - Library Category Reorder Sheet (1:1 Copy of NavbarSettingsSheet in MainTabView)
struct LibraryCategoryReorderSheet: View {
    let initialCategories: [LibraryCategoryConfig]
    let defaultCategories: [LibraryCategoryConfig]
    let onSave: ([LibraryCategoryConfig]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var localVisibleIds: [String] = []
    @State private var editMode: EditMode = .inactive

    private var categoriesById: [String: LibraryCategoryConfig] {
        Dictionary(uniqueKeysWithValues: defaultCategories.map { ($0.id, $0) })
    }

    private var inactiveCategories: [LibraryCategoryConfig] {
        let current = Set(localVisibleIds)
        return defaultCategories.filter { !current.contains($0.id) }
    }

    private func commitChanges() {
        var uniqueIds: [String] = []
        for id in localVisibleIds where categoriesById[id] != nil && !uniqueIds.contains(id) {
            uniqueIds.append(id)
        }
        if uniqueIds.isEmpty, let first = defaultCategories.first {
            uniqueIds = [first.id]
        }

        let activeSet = Set(uniqueIds)
        var merged: [LibraryCategoryConfig] = uniqueIds.compactMap { id in
            guard let def = categoriesById[id] else { return nil }
            return LibraryCategoryConfig(id: def.id, label: def.label, iconName: def.iconName, visible: true)
        }
        for def in defaultCategories where !activeSet.contains(def.id) {
            merged.append(LibraryCategoryConfig(id: def.id, label: def.label, iconName: def.iconName, visible: false))
        }
        onSave(merged)
    }

    private func toggleCategory(_ categoryId: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            if let existingIdx = localVisibleIds.firstIndex(of: categoryId) {
                guard localVisibleIds.count > 1 else {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                    return
                }
                localVisibleIds.remove(at: existingIdx)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            } else {
                if !localVisibleIds.contains(categoryId) {
                    localVisibleIds.append(categoryId)
                }
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
    }

    private func resetToDefault() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            localVisibleIds = defaultCategories.map(\.id)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(
                    header:
                        HStack {
                            Text("Angezeigte Kategorien")
                                .foregroundColor(.white.opacity(0.60))
                            Spacer()
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                    editMode = (editMode == .active ? .inactive : .active)
                                }
                            }) {
                                Text(editMode == .active ? "Fertig" : "Bearbeiten")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .textCase(nil)
                            }
                        },
                    footer:
                        Group {
                            if editMode == .active {
                                Text("Am Griff rechts anfassen, um die Position sofort zu verschieben. Den Haken tippen, um Kategorien an- oder abzuwählen.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }
                ) {
                    ForEach(localVisibleIds, id: \.self) { catId in
                        if let cat = categoriesById[catId] {
                            HStack(spacing: 12) {
                                // 1. Kategorie Icon
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 26)

                                // 2. Kategorie Titel
                                Text(cat.label)
                                    .foregroundColor(.white)
                                    .font(.system(size: 15, weight: .medium))

                                Spacer()

                                if editMode == .active {
                                    // 3. Haken zum An- und Abwählen
                                    Button(action: { toggleCategory(cat.id) }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(.white)
                                            .frame(width: 32, height: 32)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .onMove { indices, newOffset in
                        localVisibleIds.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }

                // Sektion "Weitere Optionen" wie im Navigationsleisten-Menü
                if editMode == .active && !inactiveCategories.isEmpty {
                    Section(
                        header: Text("Weitere Optionen").foregroundColor(.white.opacity(0.60)),
                        footer: Text("Tippe auf den Kreis rechts, um eine Kategorie wieder in der Bibliothek anzuzeigen.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                    ) {
                        ForEach(inactiveCategories) { cat in
                            HStack(spacing: 12) {
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.60))
                                    .frame(width: 26)

                                Text(cat.label)
                                    .foregroundColor(.white.opacity(0.85))
                                    .font(.system(size: 15))

                                Spacer()

                                // Leerer Kreis zum Hinzufügen
                                Button(action: { toggleCategory(cat.id) }) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(Color.white.opacity(0.35))
                                        .frame(width: 32, height: 32)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleCategory(cat.id)
                            }
                        }
                    }
                }

                if editMode == .active {
                    Section {
                        Button(action: resetToDefault) {
                            HStack {
                                Spacer()
                                Text("Standard-Reihenfolge wiederherstellen")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                            }
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Bibliothek-Kategorien")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        commitChanges()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                let ids = initialCategories.filter(\.visible).map(\.id).filter { categoriesById[$0] != nil }
                localVisibleIds = ids.isEmpty ? defaultCategories.map(\.id) : ids
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        editMode = .active
                    }
                }
            }
            .onDisappear {
                commitChanges()
            }
        }
        .preferredColorScheme(.dark)
    }
}
