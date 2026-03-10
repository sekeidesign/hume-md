//
//  EditorViewController+EmptyState.swift
//  MarkEditMac
//
//  Empty state overlay shown when a folder is open but no file is selected.

import AppKit
import ObjectiveC

private var emptyStateKey: UInt8 = 0

extension EditorViewController {
  var emptyStateView: NSView? {
    get { objc_getAssociatedObject(self, &emptyStateKey) as? NSView }
    set { objc_setAssociatedObject(self, &emptyStateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
  }
}

extension EditorViewController {
  func setUpEmptyStateIfNeeded() {
    guard emptyStateView == nil else { return }

    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false

    let icon = NSImageView()
    icon.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
    icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 40, weight: .thin)
    icon.contentTintColor = .tertiaryLabelColor
    icon.translatesAutoresizingMaskIntoConstraints = false

    let title = makeEmptyStateLabel("Select a file to start editing", size: 15, weight: .medium, color: .secondaryLabelColor)
    let subtitle = makeEmptyStateLabel("Open a folder using the toolbar, then pick a file from the sidebar", size: 12, weight: .regular, color: .tertiaryLabelColor)
    subtitle.maximumNumberOfLines = 2
    subtitle.alignment = .center

    container.addSubview(icon)
    container.addSubview(title)
    container.addSubview(subtitle)

    NSLayoutConstraint.activate([
      icon.topAnchor.constraint(equalTo: container.topAnchor),
      icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      icon.widthAnchor.constraint(equalToConstant: 48),
      icon.heightAnchor.constraint(equalToConstant: 48),

      title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 12),
      title.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      title.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      title.trailingAnchor.constraint(equalTo: container.trailingAnchor),

      subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
      subtitle.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      subtitle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      subtitle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      subtitle.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])

    view.addSubview(container)
    NSLayoutConstraint.activate([
      container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      container.widthAnchor.constraint(lessThanOrEqualToConstant: 260),
    ])

    emptyStateView = container
    updateEmptyState()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(updateEmptyStateFromNotification(_:)),
      name: RepositoryManager.repositoryDidChange,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(updateEmptyStateFromNotification(_:)),
      name: RepositoryManager.selectedFileDidChange,
      object: nil
    )
  }

  func updateEmptyState() {
    let show = RepositoryManager.shared.repository != nil && RepositoryManager.shared.selectedFile == nil
    emptyStateView?.isHidden = !show
    webView.isHidden = show
  }
}

// MARK: - Private

private extension EditorViewController {
  @objc func updateEmptyStateFromNotification(_ notification: Notification) {
    updateEmptyState()
  }

  func makeEmptyStateLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = NSFont.systemFont(ofSize: size, weight: weight)
    label.textColor = color
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }
}
