import AppIntents
import Foundation

struct AddBrainDumpThoughtIntent: AppIntent {
    static var title: LocalizedStringResource = "Add to Brain Dump"
    static var description = IntentDescription("Save a thought to your Brain Dump inbox, ready to organise later.")
    static var openAppWhenRun = false

    @Parameter(title: "Thought", requestValueDialog: "What would you like to add to Brain Dump?")
    var thought: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        _ = try save(to: ThoughtStore.shared)
        return .result(dialog: "Added to your Brain Dump inbox.")
    }

    /// The intent and tests use the same capture path; production supplies the shared store.
    @MainActor
    func save(to store: ThoughtStore) throws -> ThoughtRecord {
        let text = thought.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw $thought.needsValueError("What would you like to add?") }
        return try store.capture(text: text)
    }
}

struct BrainDumpShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddBrainDumpThoughtIntent(),
                    phrases: ["Add to \(.applicationName)", "Add a thought to \(.applicationName)", "Capture a thought in \(.applicationName)"],
                    shortTitle: "Add a thought", systemImageName: "brain.head.profile")
    }
}
