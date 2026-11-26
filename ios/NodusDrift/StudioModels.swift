// SPDX-License-Identifier: MIT
import Foundation
import Security
import StableAudioMLX
import SwiftUI

enum StudioCredentials {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.drakonis96.nodusdrift.huggingface", kSecAttrAccount as String: "token"]
    }
    static func load() -> String? {
        var request = query; request[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ token: String) throws {
        var request = query
        request[kSecValueData as String] = Data(token.utf8)
        request[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(request as CFDictionary, nil)
        if status == errSecDuplicateItem {
            guard SecItemUpdate(query as CFDictionary, [kSecValueData as String: Data(token.utf8)] as CFDictionary) == errSecSuccess else { throw StudioError.invalid("Could not update the token in Keychain.") }
        } else if status != errSecSuccess { throw StudioError.invalid("Could not save the token in Keychain.") }
    }
    static func delete() { SecItemDelete(query as CFDictionary) }
}

@MainActor final class StudioModels: ObservableObject {
    @Published private(set) var installed: Set<SA3ModelKind> = []
    @Published private(set) var status = ""
    @Published private(set) var progress: Double = 0
    @Published private(set) var busy = false
    @Published private(set) var account: String?
    @Published var acceptedTerms: Bool { didSet { defaults.set(acceptedTerms, forKey: "studio.modelTerms.v1") } }
    let directory: SA3ModelDirectory
    private let downloads: URL
    private let defaults: UserDefaults
    private var work: Task<Void, Never>?
    var bytesOnDisk: Int64 { directory.bytesOnDisk() }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        acceptedTerms = defaults.bool(forKey: "studio.modelTerms.v1")
        account = defaults.string(forKey: "studio.hfAccount")
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = SA3ModelDirectory(root: support.appendingPathComponent("StudioModels", isDirectory: true))
        downloads = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("StudioModelDownloads", isDirectory: true)
        refresh()
    }
    func refresh() { installed = Set(SA3ModelKind.allCases.filter(directory.isReady)) }
    func signIn(token: String) async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            let clean = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard clean.hasPrefix("hf_"), clean.count <= 300 else { throw StudioError.invalid("Enter a Hugging Face read token.") }
            var request = URLRequest(url: URL(string: "https://huggingface.co/api/whoami-v2")!)
            request.setValue("Bearer \(clean)", forHTTPHeaderField: "Authorization")
            let session = URLSession(configuration: .ephemeral); defer { session.invalidateAndCancel() }
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let name = object["name"] as? String else { throw StudioError.invalid("Hugging Face did not accept this token.") }
            try StudioCredentials.save(clean)
            account = name; defaults.set(name, forKey: "studio.hfAccount"); status = "Signed in to Hugging Face."
        } catch { status = error.localizedDescription }
    }
    func signOut() { guard !busy else { return }; StudioCredentials.delete(); account = nil; defaults.removeObject(forKey: "studio.hfAccount") }
    func install(_ kind: SA3ModelKind) {
        guard !busy, !installed.contains(kind) else { return }
        guard SA3Engine.isSupported else { status = "Local audio generation needs a real device. Studio works in Simulator."; return }
        guard acceptedTerms, let token = StudioCredentials.load() else { status = "Read the model terms and sign in with a Hugging Face read token first."; return }
        busy = true; progress = 0
        let directory = directory, downloads = downloads
        work = Task { [weak self] in
            defer { self?.busy = false; self?.work = nil; self?.refresh() }
            do {
                // Reuse already-converted shared weights when installing the second model.
                let outputs: [String: URL] = [
                    SA3Manifest.t5.fileName: directory.t5, SA3Manifest.decoder.fileName: directory.decoder,
                    SA3Manifest.encoder.fileName: directory.encoder, SA3Manifest.tokenizer.fileName: directory.tokenizer,
                    SA3Manifest.licence.fileName: directory.root.appendingPathComponent(SA3Manifest.licence.fileName),
                    SA3Manifest.gemmaLicence.fileName: directory.root.appendingPathComponent(SA3Manifest.gemmaLicence.fileName)
                ]
                let files = SA3Manifest.files(for: [kind]).filter { file in
                    guard let output = outputs[file.fileName] else { return true }
                    return !FileManager.default.fileExists(atPath: output.path)
                }
                try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: directory.root, withIntermediateDirectories: true)
                Self.excludeBackup(directory.root); Self.excludeBackup(downloads)
                let required = files.reduce(Int64(0)) { $0 + $1.bytes } * 2 + 300_000_000
                let free = try downloads.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? 0
                guard free > required else { throw StudioError.invalid("At least \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)) of free space is needed while installing.") }
                let session = URLSession(configuration: .ephemeral)
                defer { session.invalidateAndCancel() }
                for (index, file) in files.enumerated() {
                    try Task.checkCancellation()
                    self?.status = "Downloading \(file.fileName) (\(index + 1)/\(files.count))"
                    let destination = downloads.appendingPathComponent(file.fileName)
                    let verified = await Task.detached(priority: .utility) { (try? SA3Installer.verify(destination, against: file)) != nil }.value
                    if !verified {
                        var request = URLRequest(url: SA3Manifest.url(file)); request.timeoutInterval = 120
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        let (temporary, response) = try await session.download(for: request)
                        defer { try? FileManager.default.removeItem(at: temporary) }
                        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                            throw StudioError.invalid("Hugging Face download failed (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)). Check access and try again.")
                        }
                        try await Task.detached(priority: .utility) { try SA3Installer.verify(temporary, against: file) }.value
                        try Task.checkCancellation()
                        try? FileManager.default.removeItem(at: destination)
                        try FileManager.default.moveItem(at: temporary, to: destination)
                    }
                    self?.progress = Double(index + 1) / Double(files.count + 1)
                }
                self?.status = "Preparing models on this device…"
                let converter = Task.detached(priority: .utility) { try SA3Installer.prepare(kinds: [kind], downloads: downloads, directory: directory, deleteArchives: true) }
                try await withTaskCancellationHandler { try await converter.value } onCancel: { converter.cancel() }
                try Task.checkCancellation()
                if let notice = Bundle.main.resourceURL?.appendingPathComponent("Legal/NOTICE.txt") {
                    let target = directory.root.appendingPathComponent("NOTICE.txt")
                    try? FileManager.default.removeItem(at: target)
                    try FileManager.default.copyItem(at: notice, to: target)
                }
                try? FileManager.default.removeItem(at: downloads)
                self?.progress = 1; self?.status = "Stable Audio 3 \(kind.displayName) is ready."
            } catch { self?.status = Task.isCancelled ? "Installation cancelled. Verified files can be reused." : String(describing: error) }
        }
    }
    func cancel() { work?.cancel(); status = "Cancelling…" }
    func remove(_ kind: SA3ModelKind) {
        guard !busy else { return }
        SA3Installer.remove(kind, from: directory)
        try? FileManager.default.removeItem(at: downloads)
        refresh(); status = "Model removed. Your generated recordings are kept."
    }
    func clearDownloads() {
        guard !busy else { return }
        try? FileManager.default.removeItem(at: downloads); status = "Temporary model downloads removed."
    }
    nonisolated private static func excludeBackup(_ url: URL) {
        var url = url; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
