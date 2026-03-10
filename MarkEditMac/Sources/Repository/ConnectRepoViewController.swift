//
//  ConnectRepoViewController.swift
//  MarkEditMac
//
//  Sheet VC to connect an existing local repo or clone a new one.

import AppKit

final class ConnectRepoViewController: NSViewController {

  // MARK: - Private Views

  private let segmentedControl = NSSegmentedControl()
  private let stackView = NSStackView()

  // "Open Local" panel
  private let localPathLabel = NSTextField()
  private let chooseFolderButton = NSButton()

  // "Clone" panel
  private let cloneURLField = NSTextField()
  private let cloneURLLabel = NSTextField()

  private let connectButton = NSButton()
  private let cancelButton = NSButton()
  private let progressIndicator = NSProgressIndicator()
  private let statusLabel = NSTextField()

  private var localURL: URL?

  // MARK: - Lifecycle

  override func loadView() {
    view = NSView(frame: CGRect(x: 0, y: 0, width: 440, height: 230))
    buildLayout()
    updateMode()
  }

  // MARK: - Layout

  private func buildLayout() {
    // Title label
    let titleLabel = makeLabel("Connect Repository", font: NSFont.boldSystemFont(ofSize: 14))
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(titleLabel)

    // Segmented control: Open Local | Clone
    segmentedControl.segmentCount = 2
    segmentedControl.setLabel("Open Local", forSegment: 0)
    segmentedControl.setLabel("Clone", forSegment: 1)
    segmentedControl.selectedSegment = 0
    segmentedControl.target = self
    segmentedControl.action = #selector(segmentChanged(_:))
    segmentedControl.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(segmentedControl)

    // --- Open Local area ---
    localPathLabel.isEditable = false
    localPathLabel.isSelectable = false
    localPathLabel.isBordered = true
    localPathLabel.drawsBackground = true
    localPathLabel.placeholderString = "No folder selected"
    localPathLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(localPathLabel)

    chooseFolderButton.bezelStyle = .rounded
    chooseFolderButton.title = "Choose…"
    chooseFolderButton.target = self
    chooseFolderButton.action = #selector(chooseLocalFolder(_:))
    chooseFolderButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(chooseFolderButton)

    // --- Clone area ---
    cloneURLLabel.isEditable = false
    cloneURLLabel.isSelectable = false
    cloneURLLabel.isBordered = false
    cloneURLLabel.drawsBackground = false
    cloneURLLabel.stringValue = "Repository URL:"
    cloneURLLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(cloneURLLabel)

    cloneURLField.placeholderString = "https://github.com/user/repo.git"
    cloneURLField.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(cloneURLField)

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

    // Connect button
    connectButton.bezelStyle = .rounded
    connectButton.title = "Connect"
    connectButton.keyEquivalent = "\r"
    connectButton.target = self
    connectButton.action = #selector(connectAction(_:))
    connectButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(connectButton)

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

      segmentedControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
      segmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),

      localPathLabel.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
      localPathLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      localPathLabel.trailingAnchor.constraint(equalTo: chooseFolderButton.leadingAnchor, constant: -8),

      chooseFolderButton.centerYAnchor.constraint(equalTo: localPathLabel.centerYAnchor),
      chooseFolderButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

      cloneURLLabel.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
      cloneURLLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

      cloneURLField.topAnchor.constraint(equalTo: cloneURLLabel.bottomAnchor, constant: 6),
      cloneURLField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      cloneURLField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

      progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      progressIndicator.bottomAnchor.constraint(equalTo: connectButton.topAnchor, constant: -8),

      statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      statusLabel.bottomAnchor.constraint(equalTo: connectButton.topAnchor, constant: -8),

      connectButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
      connectButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      connectButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),

      cancelButton.centerYAnchor.constraint(equalTo: connectButton.centerYAnchor),
      cancelButton.trailingAnchor.constraint(equalTo: connectButton.leadingAnchor, constant: -8),
      cancelButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
    ])
  }

  private func makeLabel(_ text: String, font: NSFont) -> NSTextField {
    let label = NSTextField()
    label.isEditable = false
    label.isSelectable = false
    label.isBordered = false
    label.drawsBackground = false
    label.stringValue = text
    label.font = font
    return label
  }

  private func updateMode() {
    let isLocalMode = segmentedControl.selectedSegment == 0
    localPathLabel.isHidden = !isLocalMode
    chooseFolderButton.isHidden = !isLocalMode
    cloneURLLabel.isHidden = isLocalMode
    cloneURLField.isHidden = isLocalMode
    connectButton.title = isLocalMode ? "Connect" : "Clone"
    statusLabel.stringValue = ""
  }

  // MARK: - Actions

  @objc private func segmentChanged(_ sender: Any?) {
    updateMode()
  }

  @objc private func chooseLocalFolder(_ sender: Any?) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Select Repository"

    guard let window = view.window else { return }
    panel.beginSheetModal(for: window) { [weak self] response in
      guard response == .OK, let url = panel.url else { return }

      // Validate .git exists
      let gitDir = url.appendingPathComponent(".git")
      guard FileManager.default.fileExists(atPath: gitDir.path) else {
        self?.statusLabel.stringValue = "Selected folder is not a git repository."
        return
      }

      self?.localURL = url
      self?.localPathLabel.stringValue = url.path
      self?.statusLabel.stringValue = ""
    }
  }

  @objc private func connectAction(_ sender: Any?) {
    if segmentedControl.selectedSegment == 0 {
      openLocal()
    } else {
      cloneRepository()
    }
  }

  @objc private func cancelAction(_ sender: Any?) {
    dismiss(self)
  }

  // MARK: - Open Local

  private func openLocal() {
    guard let url = localURL else {
      statusLabel.stringValue = "Please choose a local repository folder."
      return
    }

    let remoteURL = (try? GitService.shared.remoteURL(in: url)) ?? ""
    let repo = RepositoryModel(localPath: url, remoteURL: remoteURL)
    RepositoryManager.shared.loadRepository(repo)
    dismiss(self)
  }

  // MARK: - Clone

  private func cloneRepository() {
    let urlString = cloneURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !urlString.isEmpty else {
      statusLabel.stringValue = "Please enter a repository URL."
      return
    }

    // Derive destination folder name from last path component
    let repoName = URL(string: urlString)?.deletingPathExtension().lastPathComponent ?? "repo"
    guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    let destinationURL = documentsURL.appendingPathComponent("MarkEdit/\(repoName)")

    setLoading(true)
    statusLabel.stringValue = "Cloning…"

    Task {
      do {
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try await GitService.shared.clone(url: urlString, to: destinationURL)
        let remoteURL = (try? GitService.shared.remoteURL(in: destinationURL)) ?? urlString
        let repo = RepositoryModel(localPath: destinationURL, remoteURL: remoteURL)
        await MainActor.run {
          RepositoryManager.shared.loadRepository(repo)
          self.setLoading(false)
          self.dismiss(self)
        }
      } catch {
        await MainActor.run {
          self.setLoading(false)
          self.statusLabel.stringValue = error.localizedDescription
        }
      }
    }
  }

  private func setLoading(_ loading: Bool) {
    connectButton.isEnabled = !loading
    cancelButton.isEnabled = !loading
    progressIndicator.isHidden = !loading
    if loading {
      progressIndicator.startAnimation(nil)
    } else {
      progressIndicator.stopAnimation(nil)
    }
  }
}
