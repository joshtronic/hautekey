import AppKit
import HauteKeyCore
import SwiftUI

/// A plain-text editor for config.json. Save is refused until the text is valid, so the app
/// never writes a broken file.
struct RawConfigEditor: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var error: ConfigError?

    init(model: AppModel) {
        self.model = model
        _text = State(initialValue: model.file.rawText() ?? String(decoding: ConfigCodec.encode(model.config), as: UTF8.self))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.file.resolvedURL().path(percentEncoded: false).replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.callout).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Show in Finder", action: model.revealConfigFile)
                    .buttonStyle(.link)
            }
            PlainTextEditor(text: $text)
                .frame(minWidth: 520, minHeight: 420)
                .border(.separator)
            if let error {
                Label(error.description, systemImage: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    error = model.saveRaw(text)
                    if error == nil { dismiss() }
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .padding(16)
    }
}

/// NSTextView with smart quotes, dashes, and text replacement turned off; those would corrupt JSON.
private struct PlainTextEditor: NSViewRepresentable {
    @SwiftUI.Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.string = text
        textView.delegate = context.coordinator
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        if textView.string != text { textView.string = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let text: SwiftUI.Binding<String>

        init(text: SwiftUI.Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}
