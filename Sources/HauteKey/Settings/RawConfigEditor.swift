import AppKit
import HauteKeyCore
import SwiftUI

/// A plain-text editor for the settings file. Checks the text as you type, highlights the line
/// with the problem, and won't save until it's valid, so the app never writes a broken file.
struct RawConfigEditor: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var error: ConfigError?
    @State private var validation: Task<Void, Never>?

    init(model: AppModel) {
        self.model = model
        let initial = model.file.rawText() ?? String(decoding: ConfigCodec.encode(model.config), as: UTF8.self)
        _text = State(initialValue: initial)
        _error = State(initialValue: Self.validate(initial))
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
            CodeTextView(text: $text, errorLine: error?.line(in: text))
                .frame(minWidth: 560, minHeight: 440)
                .border(.separator)
            Group {
                if let error {
                    Label(error.description, systemImage: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.multicolor)
                } else {
                    Label("Looks good", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    error = model.saveRaw(text)
                    if error == nil { dismiss() }
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(error != nil)
            }
        }
        .padding(16)
        .onChange(of: text) { _, newText in
            validation?.cancel()
            validation = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                error = Self.validate(newText)
            }
        }
    }

    private static func validate(_ text: String) -> ConfigError? {
        do {
            _ = try ConfigCodec.decode(Data(text.utf8))
            return nil
        } catch {
            return error
        }
    }
}

/// A monospaced NSTextView with line numbers and the error line highlighted. Smart quotes,
/// dashes, and text replacement are off; they would corrupt JSON.
private struct CodeTextView: NSViewRepresentable {
    @SwiftUI.Binding var text: String
    let errorLine: Int?

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView(usingTextLayoutManager: false)
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.allowsUndo = true
        textView.isRichText = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        textView.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        let ruler = LineNumberRuler(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        context.coordinator.ruler = ruler
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView, let layout = textView.layoutManager else { return }
        if textView.string != text { textView.string = text }

        let whole = NSRange(location: 0, length: (textView.string as NSString).length)
        layout.removeTemporaryAttribute(.backgroundColor, forCharacterRange: whole)
        if let errorLine, let range = Self.range(ofLine: errorLine, in: textView.string as NSString) {
            layout.addTemporaryAttribute(.backgroundColor, value: NSColor.systemRed.withAlphaComponent(0.22), forCharacterRange: range)
        }
        context.coordinator.ruler?.errorLine = errorLine
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    private static func range(ofLine target: Int, in string: NSString) -> NSRange? {
        var line = 1
        var index = 0
        while index <= string.length {
            let lineRange = string.lineRange(for: NSRange(location: min(index, string.length), length: 0))
            if line == target { return lineRange }
            guard NSMaxRange(lineRange) > index else { return nil }
            index = NSMaxRange(lineRange)
            line += 1
        }
        return nil
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let text: SwiftUI.Binding<String>
        var ruler: LineNumberRuler?

        init(text: SwiftUI.Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            ruler?.needsDisplay = true
        }
    }
}

/// Draws line numbers beside an NSTextView, with the error line's number in red.
final class LineNumberRuler: NSRulerView {
    var errorLine: Int? { didSet { needsDisplay = true } }
    private weak var textView: NSTextView?

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 38
        NotificationCenter.default.addObserver(
            self, selector: #selector(redraw), name: NSView.boundsDidChangeNotification, object: scrollView.contentView
        )
        scrollView.contentView.postsBoundsChangedNotifications = true
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func redraw() { needsDisplay = true }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView, let layout = textView.layoutManager, let container = textView.textContainer else { return }
        let string = textView.string as NSString
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        let visibleGlyphs = layout.glyphRange(forBoundingRect: textView.visibleRect, in: container)
        let visibleChars = layout.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)

        var line = 1
        string.enumerateSubstrings(in: NSRange(location: 0, length: visibleChars.location), options: [.byLines, .substringNotRequired]) { _, _, _, _ in
            line += 1
        }

        var index = visibleChars.location
        repeat {
            let lineRange = string.lineRange(for: NSRange(location: index, length: 0))
            let glyph = layout.glyphIndexForCharacter(at: min(lineRange.location, max(string.length - 1, 0)))
            let fragment = string.length == 0
                ? layout.extraLineFragmentRect
                : layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let y = convert(NSPoint(x: 0, y: fragment.minY + textView.textContainerInset.height), from: textView).y
            let color: NSColor = line == errorLine ? .systemRed : .tertiaryLabelColor
            let label = NSAttributedString(string: "\(line)", attributes: [.font: font, .foregroundColor: color])
            label.draw(at: NSPoint(x: ruleThickness - label.size().width - 6, y: y + (fragment.height - label.size().height) / 2))
            line += 1
            index = NSMaxRange(lineRange)
        } while index < NSMaxRange(visibleChars)
    }
}
