//
//  MessageBubbleView.swift
//  TestStealthyUI
//
//  AppKit-based message bubble with MessageKit-style constraint layout.
//  Ensures precise trailing/leading alignment for chat bubbles.
//

import SwiftUI
#if os(macOS)
import AppKit

// MARK: - AppKit Bubble Container
/// Custom NSView that mimics MessageKit's constraint-based bubble layout.
/// Uses Auto Layout to pin bubbles to trailing (user) or leading (assistant) edges.
class BubbleContainerView: NSView {
    // MARK: - Properties
    private let bubbleView = NSView()
    private let textField = NSTextField()

    var text: String = "" {
        didSet {
            textField.stringValue = text
            needsLayout = true
        }
    }

    var isUser: Bool = true {
        didSet {
            updateLayout()
            updateAppearance()
        }
    }

    var maxBubbleWidth: CGFloat = 300 {
        didSet {
            updateLayout()
        }
    }

    private var bubbleConstraints: [NSLayoutConstraint] = []

    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupLayout()
    }

    // MARK: - Setup
    private func setupViews() {
        wantsLayer = true

        // Configure bubble
        bubbleView.wantsLayer = true
        bubbleView.layer?.cornerRadius = 16
        bubbleView.layer?.cornerCurve = .continuous
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bubbleView)

        // Configure text field (MessageKit-style)
        textField.isBordered = false
        textField.isEditable = false
        textField.isSelectable = false
        textField.backgroundColor = .clear
        textField.drawsBackground = false
        textField.font = .preferredFont(forTextStyle: .body)
        textField.alignment = .left  // Always left-aligned inside bubble
        textField.lineBreakMode = .byWordWrapping
        textField.maximumNumberOfLines = 0
        textField.cell?.wraps = true
        textField.cell?.isScrollable = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(textField)

        // Text field constraints within bubble (fixed)
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            textField.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            textField.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12)
        ])
    }

    private func setupLayout() {
        updateLayout()
        updateAppearance()
    }

    /// Updates bubble constraints based on message role (MessageKit approach)
    private func updateLayout() {
        // Remove old constraints
        NSLayoutConstraint.deactivate(bubbleConstraints)
        bubbleConstraints.removeAll()

        // Common constraints (top/bottom)
        let topConstraint = bubbleView.topAnchor.constraint(equalTo: topAnchor)
        let bottomConstraint = bubbleView.bottomAnchor.constraint(equalTo: bottomAnchor)

        // Width constraint (intrinsic but capped)
        let widthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: maxBubbleWidth)
        widthConstraint.priority = .required

        bubbleConstraints = [topConstraint, bottomConstraint, widthConstraint]

        if isUser {
            // User messages: pin to trailing edge (MessageKit style)
            let trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
            trailingConstraint.priority = .required

            // Leading constraint with lower priority to allow shrinking
            let leadingConstraint = bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40)
            leadingConstraint.priority = NSLayoutConstraint.Priority(rawValue: 750)

            bubbleConstraints.append(contentsOf: [trailingConstraint, leadingConstraint])
        } else {
            // Assistant messages: pin to leading edge (MessageKit style)
            let leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16)
            leadingConstraint.priority = .required

            // Trailing constraint with lower priority to allow shrinking
            let trailingConstraint = bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40)
            trailingConstraint.priority = NSLayoutConstraint.Priority(rawValue: 750)

            bubbleConstraints.append(contentsOf: [leadingConstraint, trailingConstraint])
        }

        NSLayoutConstraint.activate(bubbleConstraints)
    }

    private func updateAppearance() {
        if isUser {
            // User bubble: subtle background
            bubbleView.layer?.backgroundColor = NSColor.secondarySystemFill.withAlphaComponent(0.22).cgColor
            textField.textColor = .labelColor
        } else {
            // Assistant: no bubble, just text
            bubbleView.layer?.backgroundColor = NSColor.clear.cgColor
            textField.textColor = .labelColor
        }
    }

    override var intrinsicContentSize: NSSize {
        let labelSize = textField.intrinsicContentSize
        let bubbleWidth = min(labelSize.width + 24, maxBubbleWidth)  // 12pt padding each side
        let bubbleHeight = labelSize.height + 16  // 8pt padding top/bottom
        return NSSize(width: bubbleWidth, height: bubbleHeight)
    }
}

// MARK: - SwiftUI Wrapper
/// SwiftUI wrapper for AppKit-based bubble view.
/// Uses MessageKit-style Auto Layout constraints for precise alignment.
struct MessageBubbleView: NSViewRepresentable {
    let text: String
    let isUser: Bool
    let maxWidth: CGFloat

    func makeNSView(context: Context) -> BubbleContainerView {
        let view = BubbleContainerView()
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        return view
    }

    func updateNSView(_ nsView: BubbleContainerView, context: Context) {
        nsView.text = text
        nsView.isUser = isUser
        nsView.maxBubbleWidth = maxWidth
    }
}

#else
// iOS/UIKit version (if needed)
import UIKit

class BubbleContainerView: UIView {
    private let bubbleView = UIView()
    private let textLabel = UILabel()

    var text: String = "" {
        didSet {
            textLabel.text = text
            setNeedsLayout()
        }
    }

    var isUser: Bool = true {
        didSet {
            updateLayout()
            updateAppearance()
        }
    }

    var maxBubbleWidth: CGFloat = 300 {
        didSet {
            updateLayout()
        }
    }

    private var bubbleConstraints: [NSLayoutConstraint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupLayout()
    }

    private func setupViews() {
        bubbleView.layer.cornerRadius = 16
        bubbleView.layer.cornerCurve = .continuous
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bubbleView)

        textLabel.numberOfLines = 0
        textLabel.font = .preferredFont(forTextStyle: .body)
        textLabel.adjustsFontForContentSizeCategory = true
        textLabel.textAlignment = .left
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(textLabel)

        NSLayoutConstraint.activate([
            textLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            textLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            textLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            textLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12)
        ])
    }

    private func setupLayout() {
        updateLayout()
        updateAppearance()
    }

    private func updateLayout() {
        NSLayoutConstraint.deactivate(bubbleConstraints)
        bubbleConstraints.removeAll()

        let topConstraint = bubbleView.topAnchor.constraint(equalTo: topAnchor)
        let bottomConstraint = bubbleView.bottomAnchor.constraint(equalTo: bottomAnchor)
        let widthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: maxBubbleWidth)
        widthConstraint.priority = .required

        bubbleConstraints = [topConstraint, bottomConstraint, widthConstraint]

        if isUser {
            let trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
            trailingConstraint.priority = .required
            let leadingConstraint = bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40)
            leadingConstraint.priority = .defaultHigh
            bubbleConstraints.append(contentsOf: [trailingConstraint, leadingConstraint])
        } else {
            let leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16)
            leadingConstraint.priority = .required
            let trailingConstraint = bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40)
            trailingConstraint.priority = .defaultHigh
            bubbleConstraints.append(contentsOf: [leadingConstraint, trailingConstraint])
        }

        NSLayoutConstraint.activate(bubbleConstraints)
    }

    private func updateAppearance() {
        if isUser {
            bubbleView.backgroundColor = UIColor.secondarySystemFill.withAlphaComponent(0.22)
            textLabel.textColor = .label
        } else {
            bubbleView.backgroundColor = .clear
            textLabel.textColor = .label
        }
    }

    override var intrinsicContentSize: CGSize {
        let labelSize = textLabel.intrinsicContentSize
        let bubbleWidth = min(labelSize.width + 24, maxBubbleWidth)
        let bubbleHeight = labelSize.height + 16
        return CGSize(width: bubbleWidth, height: bubbleHeight)
    }
}

struct MessageBubbleView: UIViewRepresentable {
    let text: String
    let isUser: Bool
    let maxWidth: CGFloat

    func makeUIView(context: Context) -> BubbleContainerView {
        let view = BubbleContainerView()
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        return view
    }

    func updateUIView(_ uiView: BubbleContainerView, context: Context) {
        uiView.text = text
        uiView.isUser = isUser
        uiView.maxBubbleWidth = maxWidth
    }
}
#endif

// MARK: - Assistant Message View
/// Plain text view for assistant messages (no bubble, full width)
struct AssistantMessageView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .foregroundStyle(.primary)
    }
}
