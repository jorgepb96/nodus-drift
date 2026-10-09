// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: DriftStore
    @State private var legalDocument: LegalDocument?
    @ScaledMetric(relativeTo: .largeTitle) private var headingSize = 35.0
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Make yourself\nat home.").font(.system(size: headingSize, design: .serif)).tracking(-0.8)
                    Text("Small details for your quiet time.").font(.subheadline).foregroundStyle(DriftTheme.muted)
                }
                VStack(spacing: 0) {
                    preference("Gentle haptics", detail: "A small response to your touch", icon: "hand.tap", key: \DriftConfiguration.haptics)
                    Divider().overlay(DriftTheme.line).padding(.horizontal, 20)
                    preference("Keep meditation awake", detail: "Keep the display on in meditation mode", icon: "sun.min", key: \DriftConfiguration.keepAwake)
                    Divider().overlay(DriftTheme.line).padding(.horizontal, 20)
                    preference("Mix with other audio", detail: "Keep music from other apps playing", icon: "music.note", key: \DriftConfiguration.mixWithOtherAudio)
                }.driftPanel()
                Label("Nodi follows your iOS Reduce Motion setting. VoiceOver keeps meditation controls visible.", systemImage: "accessibility").font(.footnote).foregroundStyle(DriftTheme.muted)
                VStack(alignment: .leading, spacing: 17) {
                    Label("A quiet app, in every sense.", systemImage: "lock.shield").font(.system(size: 19, design: .serif))
                    Text("All 89 sounds work offline. Your mixes and favorites stay on this device. No account, advertising, analytics or purchases.").font(.subheadline).foregroundStyle(DriftTheme.muted).lineSpacing(5)
                    Button("Read privacy policy") { legalDocument = LegalDocument(title: "Privacy policy", file: "PRIVACY.md") }.font(.subheadline)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(22).driftPanel()
                    .accessibilityElement(children: .contain).accessibilityIdentifier("settings-privacy-card")
                VStack(alignment: .leading, spacing: 16) {
                    Text("Made with Nodus").font(.system(size: 23, design: .serif))
                    Text("The quiet corner of Nodus, reimagined for iPhone and iPad. With Nodi, your familiar companion.").font(.subheadline).foregroundStyle(DriftTheme.muted).lineSpacing(4)
                    Link(destination: URL(string: "https://nodusresearch.com/")!) {
                        Label("Nodus website", systemImage: "globe")
                    }.font(.subheadline).accessibilityIdentifier("nodus-website")
                    Link(destination: URL(string: "https://github.com/jorgepb96/nodus/issues")!) {
                        Label("Nodus support", systemImage: "questionmark.circle")
                    }.font(.subheadline).accessibilityIdentifier("nodus-support")
                    Divider().overlay(DriftTheme.line)
                    Text("Sound catalogue by Moodist").font(.subheadline.weight(.medium))
                    Text("Moodist’s catalogue data is MIT licensed, © 2023 MAZE. The recordings retain their own licenses; they are not covered by the Moodist code license.")
                        .font(.footnote).foregroundStyle(DriftTheme.muted).lineSpacing(4)
                    Link(destination: URL(string: "https://github.com/remvze/moodist")!) {
                        Label("Original Moodist repository", systemImage: "arrow.up.right")
                    }.font(.subheadline).accessibilityIdentifier("moodist-repository")
                    Button("Moodist license") {
                        legalDocument = LegalDocument(title: "Moodist license", file: "MOODIST_LICENSE.txt", notices: [
                            LegalNotice(title: "Nodus credits", file: "CREDITS.md"),
                            LegalNotice(title: "GNU AGPL v3", file: "AGPL-3.0.txt"),
                            LegalNotice(title: "Original Nodi & N · MIT", file: "NODUS_HISTORICAL_MIT.txt")
                        ])
                    }.font(.subheadline).accessibilityIdentifier("moodist-license")
                }.frame(maxWidth: .infinity, alignment: .leading).padding(22).driftPanel()
                    .accessibilityElement(children: .contain).accessibilityIdentifier("settings-nodus-card")
                VStack(spacing: 8) {
                    Text("NODUS DRIFT").font(.system(size: 10, weight: .semibold)).tracking(3)
                    Text("Version \(appVersion) · Made for a quieter moment").font(.system(size: 11))
                    Text("© 2026 Jorge Pérez Burgueño and Nodus contributors").font(.system(size: 9))
                }.foregroundStyle(DriftTheme.muted).frame(maxWidth: .infinity).padding(.vertical, 12)
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.background(DriftTheme.background).modifier(BrandToolbar())
        .sheet(item: $legalDocument) { LegalDocumentView(document: $0) }
    }
    private func preference(_ title: String, detail: String, icon: String, key: WritableKeyPath<DriftConfiguration, Bool>) -> some View {
        Toggle(isOn: Binding(get: { store.config[keyPath: key] }, set: { store.setPreference(key, $0) })) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 21, weight: .light)).foregroundStyle(DriftTheme.accent).frame(width: 25)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 14, weight: .medium))
                    Text(detail).font(.system(size: 11)).foregroundStyle(DriftTheme.muted)
                }
            }
        }.padding(20)
    }
}

struct LegalNotice: Identifiable {
    var id: String { file }
    let title: String
    let file: String
}
struct LegalDocument: Identifiable {
    var id: String { file }
    let title: String
    let file: String
    var notices: [LegalNotice] = []
}
struct LegalDocumentView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss
    private func text(for file: String) -> String {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Legal").appendingPathComponent(file),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return "This document could not be loaded." }
        // Restore paragraphs from the source's hard-wrapped lines for native wrapping.
        return content.components(separatedBy: "\n\n").filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).allSatisfy { $0 == "-" }
        }.map {
            $0.components(separatedBy: "\n").joined(separator: " ")
        }.joined(separator: "\n\n")
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    JustifiedLegalText(text: text(for: document.file))
                        .accessibilityIdentifier("legal-document-body")
                    ForEach(document.notices) { notice in
                        DisclosureGroup(notice.title) {
                            JustifiedLegalText(text: text(for: notice.file)).padding(.top, 12)
                        }.font(.subheadline)
                    }
                }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity, alignment: .leading)
            }.background(DriftTheme.background).foregroundStyle(DriftTheme.text)
                .navigationTitle(document.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

// UIKit supplies proper paragraph justification, selection and Dynamic Type.
private struct JustifiedLegalText: UIViewRepresentable {
    let text: String
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false; view.isScrollEnabled = false
        view.backgroundColor = .clear; view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .justified; paragraph.lineSpacing = 4
        view.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor(DriftTheme.text), .paragraphStyle: paragraph
        ])
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }
}
