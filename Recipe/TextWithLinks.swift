import SwiftUI

/// A view that displays plain text with clickable links.
/// Automatically detects URLs and makes them tappable, opening in the default browser.
struct TextWithLinks: View {
    let text: String
    let uiFont: UIFont
    let color: Color
    let alignment: NSTextAlignment
    /// Если указан, весь текст будет ссылкой на этот URL (даже если текст обрезан).
    let actualURL: URL?
    /// Максимальное количество строк (0 = неограниченно). Если 1, текст обрежется с многоточием.
    let maxLines: Int

    @State private var height: CGFloat = 0

    init(text: String, uiFont: UIFont, color: Color, alignment: NSTextAlignment, actualURL: URL? = nil, maxLines: Int = 0) {
        self.text = text
        self.uiFont = uiFont
        self.color = color
        self.alignment = alignment
        self.actualURL = actualURL
        self.maxLines = maxLines
    }

    var body: some View {
        GeometryReader { geometry in
            InternalTextView(
                text: text,
                uiFont: uiFont,
                color: color,
                alignment: alignment,
                actualURL: actualURL,
                maxLines: maxLines,
                width: geometry.size.width,
                height: $height
            )
            .frame(width: geometry.size.width, height: height)
        }
        .frame(height: height)
    }
}

private struct InternalTextView: UIViewRepresentable {
    let text: String
    let uiFont: UIFont
    let color: Color
    let alignment: NSTextAlignment
    let actualURL: URL?
    let maxLines: Int
    let width: CGFloat
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = true // Включаем выделение, чтобы ссылки были кликабельны
        textView.allowsEditingTextAttributes = false // Отключаем редактирование атрибутов текста
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.heightTracksTextView = true
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.maximumNumberOfLines = maxLines
        textView.dataDetectorTypes = .link
        textView.isUserInteractionEnabled = true
        textView.delegate = context.coordinator
        textView.textAlignment = alignment
        textView.tintColor = .blue // Цвет ссылок
        // Prevent horizontal expansion
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let attributedString = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.utf16.count)

        // Apply font and color
        attributedString.addAttribute(.font, value: uiFont, range: range)
        attributedString.addAttribute(.foregroundColor, value: UIColor(color), range: range)

        // Если передан actualURL, добавляем ссылку на весь текст
        if let actualURL = actualURL {
            attributedString.addAttribute(.link, value: actualURL, range: range)
        } else {
            // Detect URLs and add link attribute (UITextView will automatically style them)
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            detector?.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range {
                    attributedString.addAttribute(.link, value: match?.url as Any, range: matchRange)
                }
            }
        }

        // Apply paragraph style for alignment
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byWordWrapping
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)

        uiView.attributedText = attributedString
        uiView.textAlignment = alignment

        // Ensure width tracking is enabled
        uiView.textContainer.widthTracksTextView = true
        uiView.textContainer.lineBreakMode = .byWordWrapping
        uiView.textContainer.maximumNumberOfLines = maxLines

        // Adjust height
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        if height != size.height {
            DispatchQueue.main.async {
                height = size.height
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UITextViewDelegate {
        // For iOS 17+ use the new primaryAction method
        @available(iOS 17.0, *)
        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            if case .link(let url) = textItem.content {
                UIApplication.shared.open(url)
                // После открытия ссылки сбрасываем выделение асинхронно
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    textView.selectedTextRange = nil
                }
            }
            return nil // suppress default action
        }

        // Fallback for earlier versions (though deployment target is 26.2, this won't be called)
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
            UIApplication.shared.open(URL)
            // После открытия ссылки сбрасываем выделение асинхронно
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                textView.selectedTextRange = nil
            }
            return false
        }

        // Запрещаем изменение выделения текста, чтобы предотвратить визуальное выделение
        func textView(_ textView: UITextView, shouldChangeSelection selectedRange: NSRange) -> Bool {
            return false
        }
    }
}

// Helper to create UIFont from AppFonts
extension UIFont {
    static func customFont(name: String, size: CGFloat) -> UIFont {
        UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
    }
}

// Preview for testing
#Preview {
    TextWithLinks(
        text: "Check out this recipe: https://example.com and also http://google.com",
        uiFont: UIFont.customFont(name: "Optima", size: 16),
        color: .primary,
        alignment: .center
    )
    .padding()
}