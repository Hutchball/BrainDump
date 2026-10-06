import SwiftUI
import Combine
import UIKit
import Foundation
import UniformTypeIdentifiers
import QuartzCore
import UserNotifications
import CryptoKit
import Darwin

// MARK: - Debug Menu View

#if DEBUG
struct DebugMenuView: View {
    @Binding var showDebugPanel: Bool
    let onCreateTestTiles: () -> Void
    @Environment(\.dismiss) private var dismiss
    let exportCSVData: (() -> Data)?
    @State private var showCSVExport = false
    @State private var csvDocument = DataDocument(data: Data())
    @State private var showSpinDebug = UserDefaults.standard.bool(forKey: "ShowSpinDebug")

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Debug Panel Toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Debug Panel")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.primary)

                        HStack {
                            Text("Show Debug Panel")
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)

                            Spacer()

                            Toggle("", isOn: $showDebugPanel)
                                .onChange(of: showDebugPanel) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "ShowDebugPanel")
                                }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.15))
                                )
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Create Test Tiles Button
                    Button(action: {
                        Haptics.optionTap()
                        onCreateTestTiles()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill").foregroundStyle(Color.secondary)
                                .font(.system(size: 20))
                            Text("Create 100 Test Tiles")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                    }
                    .padding(.horizontal, 20)

                    // Spin Debug Toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Spin Debug")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.primary)

                        HStack {
                            Text("Show Spin Debug")
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)

                            Spacer()

                            Toggle("", isOn: $showSpinDebug)
                                .onChange(of: showSpinDebug) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "ShowSpinDebug")
                                }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.15))
                                )
                        )
                    }
                    .padding(.horizontal, 20)

                    Button(action: {
                        Haptics.optionTap()
                        BrainDumpNotificationManager.triggerAllDebugNotificationVariants()
                    }) {
                        HStack {
                            Image(systemName: "bell.badge.waveform.fill").foregroundStyle(Color.secondary)
                                .font(.system(size: 20))
                            Text("Trigger All Notifications")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                    }
                    .padding(.horizontal, 20)

                    if exportCSVData != nil {
                        Button(action: {
                            Haptics.optionTap()
                            csvDocument = DataDocument(data: exportCSVData?() ?? Data())
                            showCSVExport = true
                        }) {
                            HStack {
                                Image(systemName: "tablecells").foregroundStyle(Color.secondary)
                                    .font(.system(size: 20))
                                Text("Export CSV")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Haptics.optionTap()
                        dismiss()
                    }
                }
            }
            .fileExporter(
                isPresented: $showCSVExport,
                document: csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "BrainDumpTiles.csv"
            ) { _ in }
        }
    }
}

// MARK: - Debug Panel View

struct DebugPanelView: View {
    let tileCount: Int
    @StateObject private var systemMonitor = SystemMonitor()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEBUG")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.6))

            VStack(alignment: .leading, spacing: 6) {
                DebugRow(label: "Tiles", value: "\(tileCount)")
                DebugRow(label: "RAM", value: formatBytes(systemMonitor.memoryUsage))
                DebugRow(label: "Power", value: systemMonitor.powerState)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.3))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .frame(width: 140, alignment: .leading)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct DebugRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

// MARK: - System Monitor

class SystemMonitor: ObservableObject {
    @Published var memoryUsage: UInt64 = 0
    @Published var powerState: String = "Unknown"

    private var updateTimer: Timer?

    init() {
        startMonitoring()
    }

    func startMonitoring() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
        updateMetrics()
    }

    private func updateMetrics() {
        // Memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            memoryUsage = info.resident_size
        }

        // Power state
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState

        switch batteryState {
        case .charging:
            powerState = String(format: "Charging %.0f%%", batteryLevel * 100)
        case .full:
            powerState = "Full"
        case .unplugged:
            powerState = String(format: "%.0f%%", batteryLevel * 100)
        default:
            powerState = "Unknown"
        }
    }

    deinit {
        updateTimer?.invalidate()
    }
}
#endif
