import SwiftUI
import Combine
import UIKit
import Foundation
import UniformTypeIdentifiers
import QuartzCore
import UserNotifications
import CryptoKit
import Darwin

// MARK: - Tag Model

nonisolated struct Tag: Identifiable, Codable, Equatable, Sendable {
    let id: Int
    let name: String
    let color: TagColor
    let isDefault: Bool

    var uiColor: Color {
        color.uiColor
    }
}

nonisolated enum TagColor: String, Codable, CaseIterable, Sendable {
    case grey
    case yellow
    case brown
    case darkBlue
    case lightBlue
    case red
    case green
    case orange
    case purple
    case pink
    case teal
    case indigo
    case mint
    case cyan
    case rose
    case coral
    case amber
    case lime
    case emerald
    case seafoam
    case turquoise
    case sky
    case azure
    case cobalt
    case violet
    case magenta
    case plum
    case slate
    case neonPink
    case neonLime
    case neonYellow
    case neonOrange
    case neonBlue
    case neonPurple
    case neonCyan

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? TagColor.grey.rawValue
        self = TagColor(rawValue: rawValue) ?? .grey
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static let orderedPalette: [TagColor] = [
        .coral, .red, .orange, .amber, .yellow, .lime, .green,
        .emerald, .seafoam, .mint, .turquoise, .teal, .cyan, .sky,
        .lightBlue, .azure, .darkBlue, .cobalt, .indigo, .violet, .purple,
        .plum, .magenta, .pink, .rose,
        .brown, .slate, .grey,
        .neonPink, .neonLime, .neonYellow, .neonOrange, .neonBlue, .neonPurple, .neonCyan
    ]

    var uiColor: Color {
        switch self {
        case .grey: return Color(red: 0.64, green: 0.66, blue: 0.70)
        case .yellow: return Color(red: 0.99, green: 0.86, blue: 0.10)
        case .brown: return Color(red: 0.68, green: 0.44, blue: 0.18)
        case .darkBlue: return Color(red: 0.08, green: 0.32, blue: 0.82)
        case .lightBlue: return Color(red: 0.36, green: 0.76, blue: 0.98)
        case .red: return Color(red: 0.97, green: 0.28, blue: 0.20)
        case .green: return Color(red: 0.20, green: 0.79, blue: 0.26)
        case .orange: return Color(red: 0.99, green: 0.52, blue: 0.06)
        case .purple: return Color(red: 0.58, green: 0.30, blue: 0.92)
        case .pink: return Color(red: 0.97, green: 0.40, blue: 0.72)
        case .teal: return Color(red: 0.06, green: 0.72, blue: 0.68)
        case .indigo: return Color(red: 0.33, green: 0.28, blue: 0.90)
        case .mint: return Color(red: 0.46, green: 0.98, blue: 0.76)
        case .cyan: return Color(red: 0.16, green: 0.92, blue: 0.96)
        case .rose: return Color(red: 0.97, green: 0.30, blue: 0.50)
        case .coral: return Color(red: 1.00, green: 0.42, blue: 0.30)
        case .amber: return Color(red: 0.98, green: 0.66, blue: 0.00)
        case .lime: return Color(red: 0.72, green: 0.93, blue: 0.00)
        case .emerald: return Color(red: 0.00, green: 0.76, blue: 0.34)
        case .seafoam: return Color(red: 0.22, green: 0.88, blue: 0.66)
        case .turquoise: return Color(red: 0.00, green: 0.84, blue: 0.78)
        case .sky: return Color(red: 0.30, green: 0.78, blue: 1.00)
        case .azure: return Color(red: 0.00, green: 0.52, blue: 1.00)
        case .cobalt: return Color(red: 0.09, green: 0.30, blue: 0.90)
        case .violet: return Color(red: 0.70, green: 0.24, blue: 0.98)
        case .magenta: return Color(red: 0.94, green: 0.14, blue: 0.74)
        case .plum: return Color(red: 0.56, green: 0.15, blue: 0.56)
        case .slate: return Color(red: 0.44, green: 0.52, blue: 0.64)
        case .neonPink: return Color(red: 1.00, green: 0.00, blue: 0.78)
        case .neonLime: return Color(red: 0.60, green: 1.00, blue: 0.00)
        case .neonYellow: return Color(red: 1.00, green: 1.00, blue: 0.00)
        case .neonOrange: return Color(red: 1.00, green: 0.33, blue: 0.00)
        case .neonBlue: return Color(red: 0.00, green: 0.62, blue: 1.00)
        case .neonPurple: return Color(red: 0.66, green: 0.00, blue: 1.00)
        case .neonCyan: return Color(red: 0.00, green: 1.00, blue: 0.95)
        }
    }
}

// MARK: - Tag Manager

class TagManager: ObservableObject {
    @Published var tags: [Tag] = []

    private let tagsKey = "SavedTags"
    private let defaultTagId = 0 // Brain Dump
    private let maxUserTags = 20
    private let defaultTagDisplayOrder: [Int] = [0, 3, 1, 2, 4]

    init() {
        loadTags()
    }

    @Published var saveError: String?

    private func loadTags() {
        tags = ThoughtStore.shared.tags.filter { $0.isDeleted != true }.map {
            Tag(id: $0.id, name: $0.name, color: TagColor(rawValue: $0.color) ?? .grey, isDefault: $0.isDefault)
        }
        if tags.isEmpty { tags = [Tag(id: 0, name: "Brain Dump", color: .grey, isDefault: true)] }
    }

    func saveTags() {
        let store = ThoughtStore.shared
        var categories = tags.map { tag in
            var category = store.tags.first { $0.id == tag.id }
                ?? ThoughtCategory(id: tag.id, name: tag.name, color: tag.color.rawValue, isDefault: tag.isDefault)
            if category.name != tag.name || category.color != tag.color.rawValue { category.modifiedAt = Date() }
            category.name = tag.name; category.color = tag.color.rawValue; category.isDeleted = false
            return category
        }
        let retained = Set(tags.map(\.id))
        for var category in store.tags where !retained.contains(category.id) {
            if category.isDeleted != true { category.isDeleted = true; category.modifiedAt = Date() }
            categories.append(category)
        }
        do { try store.applyCategorySnapshot(categories); saveError = nil }
        catch { saveError = error.localizedDescription; loadTags() }
    }

    @discardableResult
    func addUserTag(name: String, color: TagColor, fillHex: String? = nil, borderHex: String? = nil) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAddMoreUserTags, !clean.isEmpty else { return false }
        // Random IDs avoid devices independently creating the same next integer category.
        let store = ThoughtStore.shared
        var nextId = Int.random(in: 10_000...Int(Int32.max))
        while store.tags.contains(where: { $0.id == nextId }) { nextId = Int.random(in: 10_000...Int(Int32.max)) }
        let category = ThoughtCategory(id: nextId, name: clean, color: color.rawValue, isDefault: false,
                                       fillHex: fillHex, borderHex: borderHex)
        do {
            // Commit name and both colours together, preserving deleted categories used by sync.
            try store.updateCategory(category)
            loadTags()
            saveError = nil
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }

    func deleteUserTag(_ tag: Tag) {
        guard !tag.isDefault else { return }
        let store = ThoughtStore.shared
        let reassigned = store.thoughts.filter { $0.tagId == tag.id }.map { thought in
            var value = thought; value.tagId = 0; return value
        }
        do {
            if !reassigned.isEmpty { try store.importRecords(reassigned, replacing: false) }
            tags.removeAll { $0.id == tag.id }
            saveTags()
        } catch { saveError = error.localizedDescription }
    }

    func getDefaultTag() -> Tag {
        return tags.first { $0.id == defaultTagId } ?? Tag(id: 0, name: "Brain Dump", color: .grey, isDefault: true)
    }

    func getTag(byId id: Int) -> Tag? {
        return tags.first { $0.id == id }
    }

    var defaultTagsInDisplayOrder: [Tag] {
        tags
            .filter { $0.isDefault }
            .sorted { lhs, rhs in
                let leftIndex = defaultTagDisplayOrder.firstIndex(of: lhs.id) ?? Int.max
                let rightIndex = defaultTagDisplayOrder.firstIndex(of: rhs.id) ?? Int.max
                if leftIndex != rightIndex { return leftIndex < rightIndex }
                return lhs.id < rhs.id
            }
    }

    var tagsInDisplayOrder: [Tag] {
        let fallback = defaultTagsInDisplayOrder + tags.filter { !$0.isDefault }
        let positions = Dictionary(uniqueKeysWithValues: fallback.enumerated().map { ($0.element.id, $0.offset) })
        let categories = ThoughtStore.shared.tags
        let hasCustomOrder = categories.contains { $0.displayOrder != nil }
        let saved = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.displayOrder ?? (hasCustomOrder ? Int.max : (positions[$0.id] ?? Int.max))) })
        return fallback.sorted {
            let left = saved[$0.id] ?? Int.max, right = saved[$1.id] ?? Int.max
            return left == right ? (positions[$0.id] ?? Int.max) < (positions[$1.id] ?? Int.max) : left < right
        }
    }

    func rename(_ tag: Tag, to name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, var category = ThoughtStore.shared.tags.first(where: { $0.id == tag.id }) else { return }
        category.name = clean
        do { try ThoughtStore.shared.updateCategory(category); loadTags(); saveError = nil }
        catch { saveError = error.localizedDescription }
    }

    func moveCategories(from source: IndexSet, to destination: Int, defaults: Bool) {
        var group = tagsInDisplayOrder.filter { $0.isDefault == defaults }
        group.move(fromOffsets: source, toOffset: destination)
        let other = tagsInDisplayOrder.filter { $0.isDefault != defaults }
        let ordered = defaults ? group + other : other + group
        let positions = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($0.element.id, $0.offset) })
        var categories = ThoughtStore.shared.tags
        for index in categories.indices {
            if let position = positions[categories[index].id], categories[index].displayOrder != position {
                categories[index].displayOrder = position
                categories[index].modifiedAt = Date()
            }
        }
        do { try ThoughtStore.shared.applyCategorySnapshot(categories); loadTags(); saveError = nil }
        catch { saveError = error.localizedDescription }
    }

    func resetDefaultCategories() {
        let originals: [(Int, String, TagColor)] = [
            (0, "Brain Dump", .grey), (3, "Things to do", .brown),
            (1, "Movies to watch", .darkBlue), (2, "Books to read", .yellow),
            (4, "Websites to check", .lightBlue)
        ]
        var categories = ThoughtStore.shared.tags
        for (position, original) in originals.enumerated() {
            let (id, name, color) = original
            var category = categories.first { $0.id == id }
                ?? ThoughtCategory(id: id, name: name, color: color.rawValue, isDefault: true)
            category.name = name; category.color = color.rawValue
            category.fillHex = nil; category.borderHex = nil
            category.displayOrder = position; category.isDefault = true; category.isDeleted = false
            category.modifiedAt = Date()
            if let index = categories.firstIndex(where: { $0.id == id }) { categories[index] = category }
            else { categories.append(category) }
        }
        // Keep custom categories and their relative order, after the defaults.
        for (position, tag) in tagsInDisplayOrder.filter({ !$0.isDefault }).enumerated() {
            if let index = categories.firstIndex(where: { $0.id == tag.id }) {
                categories[index].displayOrder = originals.count + position
                categories[index].modifiedAt = Date()
            }
        }
        do { try ThoughtStore.shared.applyCategorySnapshot(categories); loadTags(); saveError = nil }
        catch { saveError = error.localizedDescription }
    }

    var userTags: [Tag] {
        tags.filter { !$0.isDefault }
    }

    var canAddMoreUserTags: Bool {
        userTags.count < maxUserTags
    }
}
