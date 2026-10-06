import SwiftUI
import Combine
import UIKit
import Foundation
import UniformTypeIdentifiers
import QuartzCore
import UserNotifications
import CryptoKit
import Darwin

// MARK: - Backup Types

nonisolated struct TileBackup: Codable, Sendable {
    nonisolated struct TileRecord: Codable, Sendable {
        let id: String
        let text: String
        let tagId: Int
    }

    let version: Int
    let exportedAt: Date
    let tags: [Tag]?
    let completed: [ArchivedTile]?
    let deleted: [ArchivedTile]?
    let tiles: [TileRecord]
    var records: [ThoughtRecord]? = nil
    var categories: [ThoughtCategory]? = nil
    var attachmentData: [String: Data]? = nil
}

struct TileSummary: Identifiable {
    let id: String
    let text: String
    let tagId: Int
    let tagName: String
    var status: ThoughtRecord.Status = .active
}

struct DuplicateGroup: Identifiable {
    let id: String
    let key: String
    let items: [TileSummary]
}

nonisolated struct ArchivedTile: Identifiable, Codable, Sendable {
    let id: String
    let text: String
    let tagId: Int
    let archivedAt: Date
}

enum TrainingStep: Int, CaseIterable {
    case spinSphere
    case openTagView
    case scrollTagView
    case retagTile
    case completeTile
    case addThoughtTile
    case createFirstTile
    case swipeTags
    case readThought
    case returnHome
    case finish
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.bduBackup, .bdpBackup, .data] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct DataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum BackgroundTheme: String, CaseIterable, Identifiable {
    case space
    case gradientOne
    case gradientTwo
    case clouds
    case offBlack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .space:
            return "Space"
        case .gradientOne:
            return "Gradient One"
        case .gradientTwo:
            return "Gradient Two"
        case .clouds:
            return "Clouds"
        case .offBlack:
            return "Off-Black"
        }
    }

    var subtitle: String {
        switch self {
        case .space:
            return "Current default look"
        case .gradientOne:
            return "Simple gradient"
        case .gradientTwo:
            return "Simple gradient"
        case .clouds:
            return "Soft cloud atmosphere"
        case .offBlack:
            return "Plain dark background"
        }
    }
}

extension UTType {
    static let bduBackup = UTType(exportedAs: "com.parkinglot.bdu", conformingTo: .data)
    static let bdpBackup = UTType(exportedAs: "com.parkinglot.bdp", conformingTo: .data)
}
