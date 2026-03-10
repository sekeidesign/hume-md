//
//  PublishViewController.swift
//  MarkEditMac
//
//  Sheet VC for committing and pushing the current repository state.

import AppKit

final class PublishViewController: NSViewController {

  // MARK: - Private Views

  private let commitMessageField = NSTextField()
  private let publishButton = NSButton()
  private let cancelButton = NSButton()
  private let progressIndicator = NSProgressIndicator()
  private let statusLabel = NSTextField()

  // MARK: - Lifecycle

  override func loadView() {
    view = NSView(frame: CGRect(x: 0, y: 0, width: 400, height: 200))
    buildLayout()
  }

  // MARK: - Layout

  private func buildLayout() {
    // Title
    let titleLabel = NSTextField()
    titleLabel.isEditable = false
    titleLabel.isSelectable = false
    titleLabel.isBordered = false
    titleLabel.drawsBackground = false
    titleLabel.stringValue = "Publish Changes"
    titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(titleLabel)

    // Commit message label
    let messageLabel = NSTextField()
    messageLabel.isEditable = false
    messageLabel.isSelectable = false
    messageLabel.isBordered = false
    messageLabel.drawsBackground = false
    messageLabel.stringValue = "Commit message:"
    messageLabel.font = NSFont.systemFont(ofSize: 12)
    messageLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(messageLabel)

    // Commit message field
    commitMessageField.placeholderString = "Update content"
    commitMessageField.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(commitMessageField)

    // Progress indicator
    progressIndicator.style = .spinning
    progressIndicator.isHidden = true
    progressIndicator.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(progressIndicator)

    // Status label
    statusLabel.isEditable = false
    statusLabel.isSelectable = false
    statusLabel.isBordered = false
    statusLabel.drawsBackground = false
    statusLabel.font = NSFont.systemFont(ofSize: 11)
    statusLabel.textColor = .secondaryLabelColor
    statusLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(statusLabel)

    // Publish button
    publishButton.bezelStyle = .rounded
    publishButton.title = "Publish"
    publishButton.keyEquivalent = "\r"
    publishButton.target = self
    publishButton.action = #selector(publishAction(_:))
    publishButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(publishButton)

    // Cancel button
    cancelButton.bezelStyle = .rounded
    cancelButton.title = "Cancel"
    cancelButton.keyEquivalent = "\u{1b}"
    cancelButton.target = self
    cancelButton.action = #selector(cancelAction(_:))
    cancelButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(cancelButton)

    NSLayoutConstraint.activate([
      titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
      titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

      messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
      messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

      commitMessageField.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 6),
      commitMessageField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      commitMessageField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

      progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      progressIndicator.topAnchor.constraint(equalTo: commitMessageField.bottomAnchor, constant: 12),

      statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      statusLabel.topAnchor.constraint(equalTo: commitMessageField.bottomAnchor, constant: 12),
      statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
      statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),

      publishButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
      publishButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      publishButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),

      cancelButton.centerYAnchor.constraint(equalTo: publishButton.centerYAnchor),
      cancelButton.trailingAnchor.constraint(equalTo: publishButton.leadingAnchor, constant: -8),
      cancelButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
    ])
  }

  // MARK: - Actions

  @objc private func publishAction(_ sender: Any?) {
    guard let repoPath = RepositoryManager.shared.repository?.localPath else {
      statusLabel.stringValue = "No repository connected."
      return
    }

    let message = commitMessageField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let commitMessage = message.isEmpty ? "Update content" : message

    setLoading(true)
    statusLabel.stringValue = "Adding files…"

    Task {
      do {
        try await GitService.shared.addAll(in: repoPath)
        await MainActor.run { self.statusLabel.stringValue = "Committing…" }

        try await GitService.shared.commit(message: commitMessage, in: repoPath)
        await MainActor.run { self.statusLabel.stringValue = "Pushing…" }

        try await GitService.shared.push(in: repoPath)
        await MainActor.run {
          self.setLoading(false)
          self.statusLabel.textColor = .systemGreen
          self.statusLabel.stringValue = "Published successfully."
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.dismiss(self)
          }
        }
      } catch {
        await MainActor.run {
          self.setLoading(false)
          self.statusLabel.textColor = .systemRed
          self.statusLabel.stringValue = error.localizedDescription
        }
      }
    }
  }

  @objc private func cancelAction(_ sender: Any?) {
    dismiss(self)
  }

  // MARK: - Private Helpers

  private func setLoading(_ loading: Bool) {
    publishButton.isEnabled = !loading
    cancelButton.isEnabled = !loading
    commitMessageField.isEnabled = !loading
    progressIndicator.isHidden = !loading
    statusLabel.textColor = .secondaryLabelColor
    if loading {
      progressIndicator.startAnimation(nil)
    } else {
      progressIndicator.stopAnimation(nil)
    }
  }
}
