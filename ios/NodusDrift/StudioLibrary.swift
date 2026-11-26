// SPDX-License-Identifier: MIT
import Foundation
import CryptoKit
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let driftScene = UTType(exportedAs: "com.drakonis96.nodusdrift.scene", conformingTo: .json)
}

struct StudioArchive: Codable, FileDocument {
    static var readableContentTypes: [UTType] { [.driftScene, .json] }
    var scene: StudioScene
    var recordings: [String: Data]
    init(scene: StudioScene, recordings: [String: Data] = [:]) { self.scene = scene; self.recordings = recordings }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw StudioError.invalid("Choose a scene file.") }
        self = try Self.decode(data)
    }
    static func decode(_ data: Data) throws -> Self {
        guard data.count <= StudioScene.maximumArchiveBytes else { throw StudioError.invalid("This scene exceeds the 96 MB import limit.") }
        let archive = try JSONDecoder().decode(Self.self, from: data)
        try archive.scene.validate()
        let references = Set(archive.scene.layers.compactMap { $0.recording?.fileName })
        guard Set(archive.recordings.keys) == references else { throw StudioError.invalid("The scene's recording attachments are incomplete.") }
        for layer in archive.scene.layers {
            if let recording = layer.recording {
                guard let bytes = archive.recordings[recording.fileName], bytes.count == recording.bytes,
                      SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == recording.sha256 else {
                    throw StudioError.invalid("A recording failed its integrity check.")
                }
            }
        }
        return archive
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try scene.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= StudioScene.maximumArchiveBytes else { throw StudioError.invalid("This scene exceeds the 96 MB sharing limit.") }
        return FileWrapper(regularFileWithContents: data)
    }
}

struct StudioLibrary {
    let root: URL
    static var applicationRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SoundscapeStudio", isDirectory: true)
    }
    static var recordingsURL: URL { applicationRoot.appendingPathComponent("Recordings", isDirectory: true) }
    var recordings: URL { root.appendingPathComponent("Recordings", isDirectory: true) }
    var document: URL { root.appendingPathComponent("scenes.json") }
    var draft: URL { root.appendingPathComponent("draft.json") }

    init(root: URL = Self.applicationRoot) { self.root = root }
    func prepare() throws {
        try FileManager.default.createDirectory(at: recordings, withIntermediateDirectories: true)
    }
    func load() throws -> [StudioScene] {
        guard FileManager.default.fileExists(atPath: document.path) else { return [] }
        let data = try Data(contentsOf: document)
        guard data.count < 8_000_000 else { throw StudioError.invalid("The scene library is too large.") }
        let scenes = try JSONDecoder().decode([StudioScene].self, from: data)
        guard scenes.count <= 96, Set(scenes.map(\.id)).count == scenes.count else { throw StudioError.invalid("Invalid scene library.") }
        try scenes.forEach { try $0.validate() }
        return scenes
    }
    func loadDraft() throws -> StudioScene? {
        guard FileManager.default.fileExists(atPath: draft.path) else { return nil }
        guard (try draft.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) < 8_000_000 else { throw StudioError.invalid("The scene draft is too large.") }
        let scene = try JSONDecoder().decode(StudioScene.self, from: Data(contentsOf: draft))
        try scene.validate(); return scene
    }
    func save(_ scenes: [StudioScene]) throws {
        guard scenes.count <= 96 else { throw StudioError.invalid("Your library holds up to 96 scenes.") }
        try scenes.forEach { try $0.validate() }; try prepare()
        try JSONEncoder().encode(scenes).write(to: document, options: .atomic)
    }
    func saveDraft(_ scene: StudioScene) throws {
        try scene.validate(); try prepare()
        try JSONEncoder().encode(scene).write(to: draft, options: .atomic)
    }
    func export(_ scene: StudioScene) throws -> StudioArchive {
        var files: [String: Data] = [:]
        for recording in scene.layers.compactMap(\.recording) {
            guard StudioScene.safeAudioName(recording.fileName) else { throw StudioError.invalid("Invalid recording path.") }
            let url = recordings.appendingPathComponent(recording.fileName)
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size == recording.bytes, size <= 24_000_000 else { throw StudioError.invalid("A recording is missing or changed.") }
            files[recording.fileName] = try Data(contentsOf: url)
        }
        let archive = StudioArchive(scene: scene, recordings: files)
        // Use the same integrity validation for import and export.
        return try StudioArchive.decode(JSONEncoder().encode(archive))
    }
    func importArchive(_ archive: StudioArchive) throws -> StudioScene {
        let checked = try StudioArchive.decode(JSONEncoder().encode(archive))
        try prepare()
        // Remap attachments so an imported scene cannot overwrite an existing recording.
        var scene = checked.scene.duplicated(); scene.name = checked.scene.name
        var names: [String: String] = [:]
        var installed: [URL] = []
        do {
            for (name, data) in checked.recordings {
                let newName = UUID().uuidString.lowercased() + ".m4a"
                let url = recordings.appendingPathComponent(newName)
                try data.write(to: url, options: .atomic); installed.append(url)
                let file = try AVAudioFile(forReading: url)
                guard file.processingFormat.channelCount <= 2, file.length > 0,
                      (8_000...96_000).contains(file.processingFormat.sampleRate),
                      Double(file.length) / file.processingFormat.sampleRate <= 121 else {
                    throw StudioError.invalid("Unsupported audio attachment.")
                }
                let actualDuration = Double(file.length) / file.processingFormat.sampleRate
                guard scene.layers.compactMap(\.recording).filter({ $0.fileName == name }).allSatisfy({ abs($0.seconds - actualDuration) < 0.25 }) else {
                    throw StudioError.invalid("A recording's duration does not match the scene.")
                }
                names[name] = newName
            }
            for index in scene.layers.indices {
                if let oldName = scene.layers[index].recording?.fileName {
                    scene.layers[index].recording?.fileName = names[oldName]!
                }
            }
            return scene
        } catch {
            installed.forEach { try? FileManager.default.removeItem(at: $0) }; throw error
        }
    }
    /// Only removes recordings unreferenced by saved scenes and the current draft.
    func removeUnusedRecordings(scenes: [StudioScene], draft: StudioScene) {
        let keep = Set((scenes + [draft]).flatMap { $0.layers.compactMap { $0.recording?.fileName } })
        for url in (try? FileManager.default.contentsOfDirectory(at: recordings, includingPropertiesForKeys: nil)) ?? [] {
            if StudioScene.safeAudioName(url.lastPathComponent), !keep.contains(url.lastPathComponent) { try? FileManager.default.removeItem(at: url) }
        }
    }
}
