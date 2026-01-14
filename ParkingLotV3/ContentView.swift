//
//  ContentView.swift
//  ParkingLotV3
//
//  Created by Paul Hutchinson on 09/01/2026.
//

import SwiftUI
import CoreMotion
import Combine

// MARK: - Main View

struct ContentView: View {
    // Rotation state (in radians)
    @State private var rotationX: Double = 0.0
    @State private var rotationY: Double = 0.0
    
    // Selected tile index (nil = sphere mode)
    @State private var selectedIndex: Int? = nil
    
    // Editable text for selected tile
    @State private var tileTexts: [String] = []
    
    // Tile tags (index corresponds to tile index)
    @State private var tileTags: [Int] = []
    
    // Drag tracking
    @State private var lastDragValue: CGSize = .zero
    @State private var lastDragTime: Date = Date()
    
    // Momentum/velocity tracking
    @State private var velocityX: Double = 0.0
    @State private var velocityY: Double = 0.0
    @State private var decelerationTimer: Timer?
    
    // Tile count (starts with 30, can be increased)
    @State private var tileCount = 30
    
    // Deceleration constants (similar to Apple's scrolling)
    private let friction: Double = 0.95 // Friction per frame
    private let minVelocity: Double = 0.001 // Stop when velocity is below this
    
    // Motion tracking for parallax background
    @StateObject private var motionManager = MotionManager()
    
    // Tag management
    @StateObject private var tagManager = TagManager()
    
    // Settings sheet state
    @State private var showSettings = false
    
    // Action buttons and editing state
    @State private var isEditingTile = false
    @State private var showDeleteConfirmation = false
    @State private var tileToDelete: Int? = nil
    @State private var showTagPicker = false
    
    // UserDefaults keys for persistence
    private let tileTextsKey = "SavedTileTexts"
    private let tileCountKey = "SavedTileCount"
    private let tileTagsKey = "SavedTileTags"
    
    var body: some View {
        GeometryReader { geometry in
            mainContent(in: geometry)
        }
        .onAppear {
            initializeTiles()
        }
        .onDisappear {
            stopDeceleration()
            // Save tiles when view disappears
            saveTiles()
        }
        .onChange(of: tileTexts) { _, _ in
            // Auto-save whenever tile texts change
            saveTiles()
        }
        .onChange(of: tileCount) { _, _ in
            // Auto-save whenever tile count changes
            saveTiles()
        }
        .onChange(of: tileTags) { _, _ in
            // Auto-save whenever tile tags change
            saveTiles()
        }
        .overlay {
            overlayLayer()
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private func mainContent(in geometry: GeometryProxy) -> some View {
        ZStack {
            backgroundLayer()
            tilesLayer(in: geometry)
            controlsLayer()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDrag(value: value, containerSize: geometry.size)
                }
                .onEnded { _ in
                    handleDragEnd()
                }
        )
    }

    @ViewBuilder
    private func backgroundLayer() -> some View {
        // Cosmic background with parallax (explicitly at the back)
        CosmicBackgroundView(motionManager: motionManager)
            .ignoresSafeArea()
            .zIndex(-1000)

        // Background tap area to deselect
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                if selectedIndex != nil {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        selectedIndex = nil
                        isEditingTile = false
                    }
                }
            }
            .zIndex(0)
    }

    @ViewBuilder
    private func tilesLayer(in geometry: GeometryProxy) -> some View {
        // Sphere container with drag gesture
        ForEach(0..<tileCount, id: \.self) { index in
            TileView(
                index: index,
                text: tileTexts[safe: index] ?? "",
                isSelected: selectedIndex == index,
                isEditing: isEditingTile && selectedIndex == index,
                rotationX: rotationX,
                rotationY: rotationY,
                containerSize: geometry.size,
                totalCount: tileCount,
                tagId: tileTags[safe: index] ?? tagManager.getDefaultTag().id,
                tagManager: tagManager,
                onTap: {
                    handleTileTap(index: index)
                },
                onTextChange: { newText in
                    if tileTexts.indices.contains(index) {
                        tileTexts[index] = newText
                    }
                }
            )
        }
    }

    @ViewBuilder
    private func controlsLayer() -> some View {
        // Control buttons overlay
        VStack {
            Spacer()
            HStack {
                // Settings button (bottom left)
                GlassButton(
                    icon: "gearshape.fill",
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showSettings = true
                        }
                    }
                )
                .padding(.leading, 20)
                .padding(.bottom, 20)

                Spacer()

                // Create tile button (bottom right)
                GlassButton(
                    icon: "plus",
                    action: {
                        createTile()
                    }
                )
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .zIndex(2000) // Above tiles
    }

    @ViewBuilder
    private func overlayLayer() -> some View {
        if showSettings {
            SettingsView(
                isPresented: $showSettings,
                tagManager: tagManager,
                tileTags: $tileTags,
                onResetApp: resetApp
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }

        // Action buttons when tile is selected
        if let selectedIndexValue = selectedIndex {
            TileActionButtons(
                onClose: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        selectedIndex = nil
                        isEditingTile = false
                    }
                },
                onEdit: {
                    isEditingTile = true
                },
                onChangeTag: {
                    showTagPicker = true
                },
                onDelete: {
                    tileToDelete = selectedIndexValue
                    showDeleteConfirmation = true
                }
            )
            .zIndex(3001)
        }

        // Tag picker (shown when tile is selected - stays visible until deselected)
        if let selectedIndex = selectedIndex, selectedIndex < tileTags.count {
            TagPickerView(
                tagManager: tagManager,
                selectedTagId: Binding(
                    get: { tileTags[selectedIndex] },
                    set: { newTagId in
                        if selectedIndex < tileTags.count {
                            tileTags[selectedIndex] = newTagId
                        }
                    }
                ),
                onDismiss: {
                    // Don't dismiss tag picker when keyboard closes - only when tile is deselected
                    // The tag picker will automatically hide when selectedIndex becomes nil
                }
            )
            .zIndex(3002)
        }

        // Delete confirmation alert
        if showDeleteConfirmation, let tileIndex = tileToDelete {
            DeleteConfirmationView(
                isPresented: $showDeleteConfirmation,
                onConfirm: {
                    deleteTile(at: tileIndex)
                    showDeleteConfirmation = false
                    tileToDelete = nil
                },
                onCancel: {
                    showDeleteConfirmation = false
                    tileToDelete = nil
                }
            )
            .zIndex(3003)
        }
    }
    
    // MARK: - Initialization
    
    private func initializeTiles() {
        // Load saved tiles from UserDefaults
        if let savedTexts = UserDefaults.standard.array(forKey: tileTextsKey) as? [String],
           !savedTexts.isEmpty {
            tileTexts = savedTexts
            tileCount = UserDefaults.standard.integer(forKey: tileCountKey)
            // Ensure tileCount matches the number of texts
            if tileCount == 0 || tileCount < tileTexts.count {
                tileCount = tileTexts.count
            }
            
            // Load tile tags
            if let savedTags = UserDefaults.standard.array(forKey: tileTagsKey) as? [Int] {
                tileTags = savedTags
                // Ensure tileTags array matches tileCount exactly
                if tileTags.count < tileCount {
                    // Pad with default tag if too short
                    while tileTags.count < tileCount {
                        tileTags.append(tagManager.getDefaultTag().id)
                    }
                } else if tileTags.count > tileCount {
                    // Trim if too long
                    tileTags = Array(tileTags.prefix(tileCount))
                }
            } else {
                // Initialize all tiles with default tag
                tileTags = Array(repeating: tagManager.getDefaultTag().id, count: tileCount)
            }
        } else {
            // Initialize with dummy data if no saved data exists
            tileTexts = (0..<tileCount).map { "Tile \($0 + 1)" }
            // Initialize all tiles with default tag
            tileTags = Array(repeating: tagManager.getDefaultTag().id, count: tileCount)
            saveTiles()
        }
    }
    
    // MARK: - Persistence
    
    private func saveTiles() {
        // Save tile texts, count, and tags to UserDefaults
        UserDefaults.standard.set(tileTexts, forKey: tileTextsKey)
        UserDefaults.standard.set(tileCount, forKey: tileCountKey)
        UserDefaults.standard.set(tileTags, forKey: tileTagsKey)
    }
    
    // MARK: - Gesture Handlers
    
    private func handleDrag(value: DragGesture.Value, containerSize: CGSize) {
        // Only allow drag when no tile is selected
        guard selectedIndex == nil else { return }
        
        // Stop any ongoing deceleration
        stopDeceleration()
        
        // Calculate time delta for velocity
        let currentTime = Date()
        let timeDelta = currentTime.timeIntervalSince(lastDragTime)
        lastDragTime = currentTime
        
        // Calculate rotation delta from drag movement
        let deltaX = value.translation.width - lastDragValue.width
        let deltaY = value.translation.height - lastDragValue.height
        
        // Convert pixel movement to rotation (sensitivity factor)
        let sensitivity: Double = 0.005
        let deltaRotationY = Double(deltaX) * sensitivity
        let deltaRotationX = Double(deltaY) * sensitivity
        
        // Calculate velocity (rotation per second)
        if timeDelta > 0 {
            velocityY = deltaRotationY / timeDelta
            velocityX = deltaRotationX / timeDelta
        }
        
        // Update rotation directly (no animation during drag)
        // Allow infinite scrolling - rotations accumulate without bounds
        rotationY += deltaRotationY
        rotationX += deltaRotationX
        
        lastDragValue = value.translation
    }
    
    private func handleDragEnd() {
        // Start deceleration with momentum
        startDeceleration()
        lastDragValue = .zero
    }
    
    private func handleTileTap(index: Int) {
        // Stop deceleration when tapping
        stopDeceleration()
        
        // If already selected, do nothing
        if selectedIndex == index { return }
        
        // Animate to center with spring animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            selectedIndex = index
        }
    }
    
    // MARK: - Momentum/Deceleration
    
    private func startDeceleration() {
        // Stop any existing timer
        stopDeceleration()
        
        // Only start if there's significant velocity
        guard abs(velocityX) > minVelocity || abs(velocityY) > minVelocity else {
            return
        }
        
        // Frame rate for smooth deceleration (60 FPS)
        let frameInterval: TimeInterval = 1.0 / 60.0
        
        decelerationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { timer in
            // Check if we should continue
            guard abs(self.velocityX) > self.minVelocity || abs(self.velocityY) > self.minVelocity else {
                self.velocityX = 0
                self.velocityY = 0
                timer.invalidate()
                self.decelerationTimer = nil
                return
            }
            
            // Apply velocity to rotation
            self.rotationY += self.velocityY * frameInterval
            self.rotationX += self.velocityX * frameInterval
            
            // Apply friction to velocity
            self.velocityY *= self.friction
            self.velocityX *= self.friction
        }
    }
    
    private func stopDeceleration() {
        decelerationTimer?.invalidate()
        decelerationTimer = nil
        velocityX = 0
        velocityY = 0
    }
    
    // MARK: - Tile Management
    
    private func createTile() {
        // Stop any ongoing deceleration
        stopDeceleration()
        
        // Add a new blank tile
        tileTexts.append("")
        tileCount += 1
        
        // Assign default tag (Brain Dump) to new tile
        tileTags.append(tagManager.getDefaultTag().id)
        
        // Get the index of the newly created tile
        let newTileIndex = tileCount - 1
        
        // Animate the new tile to center and enable editing
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            selectedIndex = newTileIndex
            isEditingTile = true
        }
    }
    
    private func deleteTile(at index: Int) {
        guard index < tileTexts.count && index < tileTags.count else { return }
        
        // Remove tile data
        tileTexts.remove(at: index)
        tileTags.remove(at: index)
        tileCount -= 1
        
        // Deselect if this tile was selected
        if selectedIndex == index {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                selectedIndex = nil
                isEditingTile = false
            }
        } else if let currentSelected = selectedIndex, currentSelected > index {
            // Adjust selected index if a tile before it was deleted
            selectedIndex = currentSelected - 1
        }
    }
    
    func resetApp() {
        // Stop any ongoing deceleration
        stopDeceleration()
        
        // Clear all tiles
        tileTexts.removeAll()
        tileTags.removeAll()
        tileCount = 0
        
        // Create welcome tile
        tileTexts.append("Welcome, press plus to create more tiles")
        tileCount = 1
        tileTags.append(tagManager.getDefaultTag().id)
        
        // Deselect any selected tile
        selectedIndex = nil
        isEditingTile = false
        
        // Save the reset state
        saveTiles()
    }
}

// MARK: - Tile View

struct TileView: View {
    let index: Int
    let text: String
    let isSelected: Bool
    let isEditing: Bool
    let rotationX: Double
    let rotationY: Double
    let containerSize: CGSize
    let totalCount: Int
    let tagId: Int
    let tagManager: TagManager
    let onTap: () -> Void
    let onTextChange: (String) -> Void
    
    @FocusState private var isFocused: Bool
    
    // Fixed tile size (square) - increased for better text wrapping
    private let tileSize: CGFloat = 100
    
    // Calculate dynamic font size based on text length
    private func calculateFontSize(text: String, isSelected: Bool) -> CGFloat {
        let textLength = text.count
        
        // Base font sizes
        let baseSize: CGFloat = isSelected ? 24 : 16
        let minSize: CGFloat = isSelected ? 18 : 12
        let maxSize: CGFloat = isSelected ? 24 : 16
        
        // Calculate size reduction based on text length
        // For short text (0-10 chars): use base size
        // For medium text (11-20 chars): reduce slightly
        // For long text (21+ chars): reduce more, but not below min
        let reductionFactor: CGFloat
        if textLength <= 10 {
            reductionFactor = 1.0 // No reduction
        } else if textLength <= 20 {
            reductionFactor = 0.85 // 15% reduction
        } else if textLength <= 30 {
            reductionFactor = 0.7 // 30% reduction
        } else {
            reductionFactor = 0.6 // 40% reduction for very long text
        }
        
        let calculatedSize = baseSize * reductionFactor
        
        // Clamp between min and max
        return max(minSize, min(maxSize, calculatedSize))
    }
    
    var body: some View {
        let point3D = SphereMath.generatePoint(index: index, total: totalCount)
        let rotatedPoint = SphereMath.rotatePoint(
            point: point3D,
            rotationX: rotationX,
            rotationY: rotationY
        )
        let projected = SphereMath.projectTo2D(
            point: rotatedPoint,
            containerSize: containerSize
        )
        let depth = rotatedPoint.z
        let opacity = SphereMath.computeOpacity(depth: depth)
        
        // Center position for selected tile
        let finalPosition = isSelected
            ? CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
            : projected.position
        
        // Scale for selected tile (consistent size otherwise)
        let finalScale = isSelected ? 1.5 : 1.0
        
        // Z-index ordering (ensure tiles are always above background)
        // Depth ranges from -1 to 1, so we normalize to positive range [0, 2]
        // Then add 1 to ensure all tiles are above background (zIndex > 0)
        let normalizedDepth = (depth + 1.0) / 2.0 // 0 to 1
        let zIndex = isSelected ? 1000 : (normalizedDepth + 1.0) // 1 to 2 for normal tiles
        
        // Calculate dynamic font size based on text length
        let dynamicFontSize = calculateFontSize(text: text, isSelected: isSelected)
        
        // Get tag color
        let tag = tagManager.getTag(byId: tagId) ?? tagManager.getDefaultTag()
        let tagColor = tag.uiColor
        
        // Padding for text inside tile
        let horizontalPadding: CGFloat = 8
        let verticalPadding: CGFloat = 6
        
        TextField("", text: Binding(
            get: { text },
            set: { onTextChange($0) }
        ), axis: .vertical)
        .textFieldStyle(.plain)
        .multilineTextAlignment(.center)
        .lineLimit(nil)
        .font(.system(size: dynamicFontSize, weight: .medium))
        .foregroundColor(.primary)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(width: tileSize, height: tileSize)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(tagColor.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(tagColor.opacity(0.6), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .scaleEffect(finalScale)
        .opacity(isSelected ? 1.0 : opacity)
        .position(finalPosition)
        .zIndex(zIndex)
        .focused($isFocused)
        .onChange(of: isEditing) { newValue in
            // Focus keyboard only when edit button is pressed
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isFocused = true
                }
            } else {
                isFocused = false
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Math Helper

struct SphereMath {
    // Generate evenly distributed points on a sphere using golden angle spiral
    static func generatePoint(index: Int, total: Int) -> Point3D {
        // Handle edge case: when there's only one tile, place it at the center
        guard total > 1 else {
            return Point3D(x: 0.0, y: 0.0, z: 0.0)
        }
        
        // Golden angle in radians
        let goldenAngle = Double.pi * (3.0 - sqrt(5.0))
        
        // Normalized index (0 to 1)
        let y = 1.0 - (Double(index) / Double(total - 1)) * 2.0
        
        // Radius at this y level
        let radius = sqrt(1.0 - y * y)
        
        // Angle around the sphere
        let theta = goldenAngle * Double(index)
        
        // Convert to 3D coordinates
        let x = cos(theta) * radius
        let z = sin(theta) * radius
        
        return Point3D(x: x, y: y, z: z)
    }
    
    // Rotate a 3D point around X and Y axes
    static func rotatePoint(point: Point3D, rotationX: Double, rotationY: Double) -> Point3D {
        // Normalize angles to [-π, π] for efficient computation
        // This allows infinite scrolling while keeping calculations accurate
        let normalizedX = normalizeAngle(rotationX)
        let normalizedY = normalizeAngle(rotationY)
        
        // Rotate around Y axis first
        let cosY = cos(normalizedY)
        let sinY = sin(normalizedY)
        let x1 = point.x * cosY - point.z * sinY
        let z1 = point.x * sinY + point.z * cosY
        
        // Rotate around X axis
        let cosX = cos(normalizedX)
        let sinX = sin(normalizedX)
        let y1 = point.y * cosX - z1 * sinX
        let z2 = point.y * sinX + z1 * cosX
        
        return Point3D(x: x1, y: y1, z: z2)
    }
    
    // Normalize angle to [-π, π] range for infinite scrolling
    static func normalizeAngle(_ angle: Double) -> Double {
        let twoPi = 2.0 * Double.pi
        var normalized = angle.truncatingRemainder(dividingBy: twoPi)
        if normalized > Double.pi {
            normalized -= twoPi
        } else if normalized < -Double.pi {
            normalized += twoPi
        }
        return normalized
    }
    
    // Project 3D point to 2D screen coordinates
    static func projectTo2D(point: Point3D, containerSize: CGSize) -> ProjectedPoint {
        // Perspective projection with field of view
        let fov: Double = 2.0
        let distance: Double = 3.0
        
        // Project to 2D
        let scale = fov / (distance - point.z)
        let screenX = point.x * scale
        let screenY = point.y * scale
        
        // Convert to screen coordinates (center of container)
        // Increased scale multiplier to make sphere larger than screen
        let centerX = containerSize.width / 2
        let centerY = containerSize.height / 2
        let size = min(containerSize.width, containerSize.height)
        
        // Increased to 1.5 to make sphere significantly larger than screen
        let positionX = centerX + CGFloat(screenX * Double(size) * 1.5)
        let positionY = centerY + CGFloat(screenY * Double(size) * 1.5)
        
        return ProjectedPoint(
            position: CGPoint(x: positionX, y: positionY),
            depth: point.z
        )
    }
    
    // Compute scale based on depth (front = 1.0, back = smaller)
    static func computeScale(depth: Double) -> CGFloat {
        // Depth ranges from -1 to 1, map to scale 0.4 to 1.0
        let normalizedDepth = (depth + 1.0) / 2.0 // 0 to 1
        let scale = 0.4 + (normalizedDepth * 0.6) // 0.4 to 1.0
        return CGFloat(scale)
    }
    
    // Compute opacity based on depth (front = 1.0, back = more transparent)
    static func computeOpacity(depth: Double) -> Double {
        // Depth ranges from -1 to 1, map to opacity 0.3 to 1.0
        let normalizedDepth = (depth + 1.0) / 2.0 // 0 to 1
        let opacity = 0.3 + (normalizedDepth * 0.7) // 0.3 to 1.0
        return opacity
    }
}

// MARK: - Tag Model

struct Tag: Identifiable, Codable {
    let id: Int
    let name: String
    let color: TagColor
    let isDefault: Bool
    
    var uiColor: Color {
        color.uiColor
    }
}

enum TagColor: String, Codable {
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
    
    var uiColor: Color {
        switch self {
        case .grey: return Color.gray
        case .yellow: return Color.yellow
        case .brown: return Color.brown
        case .darkBlue: return Color(red: 0.0, green: 0.2, blue: 0.6)
        case .lightBlue: return Color(red: 0.4, green: 0.7, blue: 1.0)
        case .red: return Color.red
        case .green: return Color.green
        case .orange: return Color.orange
        case .purple: return Color.purple
        case .pink: return Color.pink
        case .teal: return Color.teal
        case .indigo: return Color.indigo
        }
    }
}

// MARK: - Tag Manager

class TagManager: ObservableObject {
    @Published var tags: [Tag] = []
    
    private let tagsKey = "SavedTags"
    private let defaultTagId = 0 // Brain Dump
    
    init() {
        loadTags()
    }
    
    private func loadTags() {
        // Load from UserDefaults or create defaults
        if let data = UserDefaults.standard.data(forKey: tagsKey),
           let decoded = try? JSONDecoder().decode([Tag].self, from: data),
           !decoded.isEmpty {
            tags = decoded
        } else {
            // Create default tags
            tags = [
                Tag(id: 0, name: "Brain Dump", color: .grey, isDefault: true),
                Tag(id: 1, name: "Movies to watch", color: .darkBlue, isDefault: true),
                Tag(id: 2, name: "Books to read", color: .yellow, isDefault: true),
                Tag(id: 3, name: "Things to do", color: .brown, isDefault: true),
                Tag(id: 4, name: "Websites to check", color: .lightBlue, isDefault: true)
            ]
            saveTags()
        }
    }
    
    func saveTags() {
        if let encoded = try? JSONEncoder().encode(tags) {
            UserDefaults.standard.set(encoded, forKey: tagsKey)
        }
    }
    
    func addUserTag(name: String, color: TagColor) {
        // Find next available ID
        let nextId = (tags.map { $0.id }.max() ?? 4) + 1
        let newTag = Tag(id: nextId, name: name, color: color, isDefault: false)
        tags.append(newTag)
        saveTags()
    }
    
    func deleteUserTag(_ tag: Tag) {
        guard !tag.isDefault else { return }
        tags.removeAll { $0.id == tag.id }
        saveTags()
    }
    
    func getDefaultTag() -> Tag {
        return tags.first { $0.id == defaultTagId } ?? tags[0]
    }
    
    func getTag(byId id: Int) -> Tag? {
        return tags.first { $0.id == id }
    }
    
    var userTags: [Tag] {
        tags.filter { !$0.isDefault }
    }
    
    var canAddMoreUserTags: Bool {
        userTags.count < 10
    }
}

// MARK: - Supporting Types

struct Point3D {
    let x: Double
    let y: Double
    let z: Double
}

struct ProjectedPoint {
    let position: CGPoint
    let depth: Double
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Motion Manager

class MotionManager: ObservableObject {
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0
    
    private let cmMotionManager: CMMotionManager
    
    init() {
        self.cmMotionManager = CMMotionManager()
        startMotionUpdates()
    }
    
    private func startMotionUpdates() {
        guard cmMotionManager.isDeviceMotionAvailable else { return }
        
        cmMotionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 FPS
        cmMotionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, error == nil else { return }
            
            // Get pitch and roll for parallax effect
            self?.pitch = motion.attitude.pitch
            self?.roll = motion.attitude.roll
        }
    }
    
    deinit {
        cmMotionManager.stopDeviceMotionUpdates()
    }
}

// MARK: - Cosmic Background View

struct CosmicBackgroundView: View {
    @ObservedObject var motionManager: MotionManager
    
    // Parallax intensity (how much background moves with device)
    private let parallaxIntensity: CGFloat = 50.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient (deep space)
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2),
                        Color(red: 0.05, green: 0.1, blue: 0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Middle layer - nebula glow (moves with parallax)
                let offsetX1 = CGFloat(motionManager.roll) * parallaxIntensity * 0.5
                let offsetY1 = CGFloat(motionManager.pitch) * parallaxIntensity * 0.5
                
                RadialGradient(
                    colors: [
                        Color(red: 0.2, green: 0.4, blue: 0.8).opacity(0.4),
                        Color(red: 0.3, green: 0.2, blue: 0.6).opacity(0.3),
                        Color.clear
                    ],
                    center: UnitPoint(
                        x: 0.5 + offsetX1 / geometry.size.width,
                        y: 0.5 + offsetY1 / geometry.size.height
                    ),
                    startRadius: 50,
                    endRadius: geometry.size.width * 0.8
                )
                
                // Top layer - bright center light (more parallax)
                let offsetX2 = CGFloat(motionManager.roll) * parallaxIntensity
                let offsetY2 = CGFloat(motionManager.pitch) * parallaxIntensity
                
                RadialGradient(
                    colors: [
                        Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.5),
                        Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.3),
                        Color.clear
                    ],
                    center: UnitPoint(
                        x: 0.5 + offsetX2 / geometry.size.width,
                        y: 0.5 + offsetY2 / geometry.size.height
                    ),
                    startRadius: 20,
                    endRadius: geometry.size.width * 0.5
                )
                
                // Stars layer (subtle parallax)
                let offsetX3 = CGFloat(motionManager.roll) * parallaxIntensity * 0.3
                let offsetY3 = CGFloat(motionManager.pitch) * parallaxIntensity * 0.3
                
                StarsView(offsetX: offsetX3, offsetY: offsetY3)
            }
        }
    }
}

// MARK: - Stars View

struct StarsView: View {
    let offsetX: CGFloat
    let offsetY: CGFloat
    
    // Generate random star positions (static so computed once)
    private static let starCount = 100
    private static let stars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = {
        var stars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []
        for _ in 0..<starCount {
            stars.append((
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.3...1.0)
            ))
        }
        return stars
    }()
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<Self.starCount, id: \.self) { index in
                let star = Self.stars[index]
                Circle()
                    .fill(Color.white)
                    .frame(width: star.size, height: star.size)
                    .opacity(star.opacity)
                    .position(
                        x: star.x * geometry.size.width + offsetX,
                        y: star.y * geometry.size.height + offsetY
                    )
            }
        }
    }
}

// MARK: - Glass Button

struct GlassButton: View {
    let icon: String
    let action: () -> Void
    
    private let buttonSize: CGFloat = 50
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.15))
                        )
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var tagManager: TagManager
    @Binding var tileTags: [Int]
    let onResetApp: () -> Void
    @State private var showTagsView = false
    @State private var showResetConfirmation = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Tap-to-dismiss background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissSettings()
                    }
                
                // Settings content (slides up from bottom)
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        // Drag indicator
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 40, height: 5)
                            .padding(.top, 10)
                        
                        // Header
                        HStack {
                            Text("Settings")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: dismissSettings) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Settings content
                        VStack(spacing: 16) {
                            SettingsRow(
                                icon: "tag.fill",
                                title: "Tags",
                                action: {
                                    showTagsView = true
                                }
                            )
                            SettingsRow(icon: "paintbrush.fill", title: "Appearance")
                            SettingsRow(icon: "bell.fill", title: "Notifications")
                            SettingsRow(icon: "lock.fill", title: "Privacy")
                            SettingsRow(icon: "info.circle.fill", title: "About")
                            SettingsRow(
                                icon: "arrow.counterclockwise",
                                title: "Reset App",
                                action: {
                                    showResetConfirmation = true
                                }
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                        .sheet(isPresented: $showTagsView) {
                            TagsView(
                                tagManager: tagManager,
                                tileTags: $tileTags
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: geometry.size.height * 0.6)
                    .overlay {
                        if showResetConfirmation {
                            ResetConfirmationView(
                                isPresented: $showResetConfirmation,
                                onConfirm: {
                                    onResetApp()
                                    dismissSettings()
                                }
                            )
                        }
                    }
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.05, blue: 0.15),
                                Color(red: 0.1, green: 0.05, blue: 0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(20, corners: [.topLeft, .topRight])
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: -5)
                }
            }
        }
        .zIndex(3000) // Above everything
    }
    
    private func dismissSettings() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 30)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tags View

struct TagsView: View {
    @ObservedObject var tagManager: TagManager
    @Binding var tileTags: [Int]
    @Environment(\.dismiss) private var dismiss
    
    @State private var showCreateTag = false
    @State private var newTagName = ""
    @State private var selectedColor: TagColor = .red
    
    let availableColors: [TagColor] = [.red, .green, .orange, .purple, .pink, .teal, .indigo]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Default tags section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Default Tags")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            ForEach(tagManager.tags.filter { $0.isDefault }) { tag in
                                TagRow(tag: tag, isDefault: true)
                            }
                        }
                        .padding(.top, 20)
                        
                        // User tags section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Your Tags")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if tagManager.canAddMoreUserTags {
                                    Button(action: {
                                        showCreateTag = true
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            if tagManager.userTags.isEmpty {
                                Text("No custom tags yet")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal, 20)
                            } else {
                                ForEach(tagManager.userTags) { tag in
                                    TagRow(tag: tag, isDefault: false, onDelete: {
                                        tagManager.deleteUserTag(tag)
                                    })
                                }
                            }
                        }
                        .padding(.top, 10)
                    }
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showCreateTag) {
                CreateTagView(
                    tagManager: tagManager,
                    newTagName: $newTagName,
                    selectedColor: $selectedColor,
                    availableColors: availableColors
                )
            }
        }
    }
}

// MARK: - Tag Row

struct TagRow: View {
    let tag: Tag
    let isDefault: Bool
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            // Color indicator
            Circle()
                .fill(tag.uiColor)
                .frame(width: 20, height: 20)
            
            Text(tag.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            if !isDefault, let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.15))
                )
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Create Tag View

struct CreateTagView: View {
    @ObservedObject var tagManager: TagManager
    @Binding var newTagName: String
    @Binding var selectedColor: TagColor
    let availableColors: [TagColor]
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Tag name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tag Name")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        TextField("Enter tag name", text: $newTagName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.15))
                                    )
                            )
                            .focused($isFocused)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Color selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 16) {
                            ForEach(availableColors, id: \.self) { color in
                                Button(action: {
                                    selectedColor = color
                                }) {
                                    Circle()
                                        .fill(color.uiColor)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                        )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        if !newTagName.isEmpty {
                            tagManager.addUserTag(name: newTagName, color: selectedColor)
                            newTagName = ""
                            selectedColor = .red
                            dismiss()
                        }
                    }
                    .foregroundColor(.white)
                    .disabled(newTagName.isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

// MARK: - Tag Picker View

struct TagPickerView: View {
    @ObservedObject var tagManager: TagManager
    @Binding var selectedTagId: Int
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                Text("Select Tag")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 16)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(tagManager.tags) { tag in
                            TagButton(
                                tag: tag,
                                isSelected: selectedTagId == tag.id,
                                action: {
                                    selectedTagId = tag.id
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(20, corners: [.topLeft, .topRight])
            .frame(height: 120)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Tag Button

struct TagButton: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tag.uiColor)
                    .frame(width: 12, height: 12)
                
                Text(tag.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? tag.uiColor.opacity(0.3) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? tag.uiColor : Color.white.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tile Action Buttons

struct TileActionButtons: View {
    let onClose: () -> Void
    let onEdit: () -> Void
    let onChangeTag: () -> Void
    let onDelete: () -> Void
    
    private let buttonSize: CGFloat = 50
    private let buttonSpacing: CGFloat = 16
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: buttonSpacing) {
                // Close button (X)
                ActionButton(
                    icon: "xmark",
                    action: onClose
                )
                
                // Edit button (pencil)
                ActionButton(
                    icon: "pencil",
                    action: onEdit
                )
                
                // Change tag button (tag)
                ActionButton(
                    icon: "tag",
                    action: onChangeTag
                )
                
                // Delete button (trash)
                ActionButton(
                    icon: "trash",
                    action: onDelete,
                    isDestructive: true
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 20)
            .padding(.top, 100)
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let action: () -> Void
    var isDestructive: Bool = false
    
    private let buttonSize: CGFloat = 50
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isDestructive ? .red : .primary)
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                        )
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Delete Confirmation View

struct DeleteConfirmationView: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // Confirmation card
            VStack(spacing: 24) {
                // Warning icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                // Title
                Text("Delete Tile?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                // Message
                Text("This action cannot be undone")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                // Buttons
                HStack(spacing: 16) {
                    // Cancel button
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.15))
                                    )
                            )
                    }
                    
                    // Delete button
                    Button(action: onConfirm) {
                        Text("Delete")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.8))
                            )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.05, blue: 0.15),
                                Color(red: 0.1, green: 0.05, blue: 0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .padding(.horizontal, 40)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        }
    }
}

// MARK: - Reset Confirmation View

struct ResetConfirmationView: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    @State private var confirmationStep: Int = 1
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    // Don't allow dismissing by tapping outside - user must cancel
                }
            
            // Confirmation card
            VStack(spacing: 24) {
                // Warning icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                // Title
                Text("Reset App?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                // Message - changes based on confirmation step
                VStack(spacing: 12) {
                    if confirmationStep == 1 {
                        Text("This will DELETE ALL TILES!")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.red)
                        
                        Text("This action is NOT REVERSIBLE")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("Are you absolutely sure you want to reset the app?")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Final Confirmation")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.red)
                        
                        Text("You are about to DELETE ALL TILES")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("This cannot be undone. Press 'Reset' one more time to confirm.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Buttons
                HStack(spacing: 16) {
                    // Cancel button
                    Button(action: {
                        confirmationStep = 1
                        isPresented = false
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.15))
                                    )
                            )
                    }
                    
                    // Confirm/Reset button
                    Button(action: {
                        if confirmationStep == 1 {
                            // First confirmation - move to second step
                            withAnimation {
                                confirmationStep = 2
                            }
                        } else {
                            // Second confirmation - proceed with reset
                            onConfirm()
                        }
                    }) {
                        Text(confirmationStep == 1 ? "Continue" : "Reset")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.8))
                            )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.05, blue: 0.15),
                                Color(red: 0.1, green: 0.05, blue: 0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .padding(.horizontal, 40)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
