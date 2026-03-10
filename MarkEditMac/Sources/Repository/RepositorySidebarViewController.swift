//
//  RepositorySidebarViewController.swift
//  MarkEditMac
//
//  NSOutlineView-based sidebar showing the file tree of a connected git repository.

import AppKit

// MARK: - Delegate Protocol

protocol RepositorySidebarDelegate: AnyObject {
  func sidebar(_ sidebar: RepositorySidebarViewController, didSelectFile file: RepositoryFileItem)
}

// MARK: - RepositorySidebarViewController

final class RepositorySidebarViewController: NSViewController {
  weak var fileLoadDelegate: RepositorySidebarDelegate?

  // MARK: - Private Views

  private let headerToolbar = NSView()
  private let scrollView = NSScrollView()
  private let outlineView = NSOutlineView()
  private let bottomBar = NSView()

  private let addButton = NSButton()
  private let connectButton = NSButton()
  private let branchLabel = NSTextField()
  private let repoNameLabel = NSTextField()

  private let columnIdentifier = NSUserInterfaceItemIdentifier("FileColumn")

  // MARK: - Lifecycle

  override func loadView() {
    view = NSView()
    buildLayout()
    observeNotifications()
    refresh()
  }

  // MARK: - Private — Layout

  private func buildLayout() {
    buildHeaderToolbar()
    buildOutlineView()
    buildBottomBar()

    headerToolbar.translatesAutoresizingMaskIntoConstraints = false
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    bottomBar.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(headerToolbar)
    view.addSubview(scrollView)
    view.addSubview(bottomBar)

    NSLayoutConstraint.activate([
      headerToolbar.topAnchor.constraint(equalTo: view.topAnchor),
      headerToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      headerToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      headerToolbar.heightAnchor.constraint(equalToConstant: 36),

      scrollView.topAnchor.constraint(equalTo: headerToolbar.bottomAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

      bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      bottomBar.heightAnchor.constraint(equalToConstant: 36),
    ])
  }

  private func buildHeaderToolbar() {
    headerToolbar.wantsLayer = false

    // "+" add button
    addButton.bezelStyle = .texturedRounded
    addButton.isBordered = false
    addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add")
    addButton.target = self
    addButton.action = #selector(showAddMenu(_:))
    addButton.translatesAutoresizingMaskIntoConstraints = false
    headerToolbar.addSubview(addButton)

    NSLayoutConstraint.activate([
      addButton.trailingAnchor.constraint(equalTo: headerToolbar.trailingAnchor, constant: -8),
      addButton.centerYAnchor.constraint(equalTo: headerToolbar.centerYAnchor),
      addButton.widthAnchor.constraint(equalToConstant: 24),
      addButton.heightAnchor.constraint(equalToConstant: 24),
    ])
  }

  private func buildOutlineView() {
    let column = NSTableColumn(identifier: columnIdentifier)
    column.resizingMask = .autoresizingMask
    outlineView.addTableColumn(column)
    outlineView.outlineTableColumn = column
    outlineView.headerView = nil
    outlineView.rowSizeStyle = .small
    outlineView.indentationPerLevel = 12
    outlineView.allowsMultipleSelection = false
    outlineView.dataSource = self
    outlineView.delegate = self
    outlineView.target = self
    outlineView.action = #selector(outlineViewClicked(_:))
    outlineView.menu = buildContextMenu()

    scrollView.documentView = outlineView
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.borderType = .noBorder
  }

  private func buildBottomBar() {
    bottomBar.wantsLayer = false

    // Divider line at top of bottom bar
    let divider = NSBox()
    divider.boxType = .separator
    divider.translatesAutoresizingMaskIntoConstraints = false
    bottomBar.addSubview(divider)

    // Branch label (leading)
    branchLabel.isEditable = false
    branchLabel.isSelectable = false
    branchLabel.isBordered = false
    branchLabel.drawsBackground = false
    branchLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
    branchLabel.textColor = .secondaryLabelColor
    branchLabel.translatesAutoresizingMaskIntoConstraints = false
    bottomBar.addSubview(branchLabel)

    // Repo name label (trailing)
    repoNameLabel.isEditable = false
    repoNameLabel.isSelectable = false
    repoNameLabel.isBordered = false
    repoNameLabel.drawsBackground = false
    repoNameLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
    repoNameLabel.textColor = .secondaryLabelColor
    repoNameLabel.alignment = .right
    repoNameLabel.translatesAutoresizingMaskIntoConstraints = false
    bottomBar.addSubview(repoNameLabel)

    NSLayoutConstraint.activate([
      divider.topAnchor.constraint(equalTo: bottomBar.topAnchor),
      divider.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
      divider.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),

      branchLabel.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 8),
      branchLabel.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
      branchLabel.trailingAnchor.constraint(lessThanOrEqualTo: repoNameLabel.leadingAnchor, constant: -4),

      repoNameLabel.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -8),
      repoNameLabel.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
      repoNameLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 120),
    ])

    // Connect button — anchored to center of the whole sidebar view, not the bottom bar
    connectButton.bezelStyle = .rounded
    connectButton.title = "Open Folder"
    connectButton.font = NSFont.systemFont(ofSize: 13)
    connectButton.target = self
    connectButton.action = #selector(connectRepository(_:))
    connectButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(connectButton)

    NSLayoutConstraint.activate([
      connectButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      connectButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
  }

  private func buildContextMenu() -> NSMenu {
    let menu = NSMenu()
    menu.addItem(withTitle: "New File Here", action: #selector(newFileHere(_:)), keyEquivalent: "")
      .target = self
    menu.addItem(withTitle: "New Folder Here", action: #selector(newFolderHere(_:)), keyEquivalent: "")
      .target = self
    menu.addItem(.separator())
    menu.addItem(withTitle: "Delete", action: #selector(deleteItem(_:)), keyEquivalent: "")
      .target = self
    return menu
  }

  // MARK: - Private — Notifications

  private func observeNotifications() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(repositoryDidChange(_:)),
      name: RepositoryManager.repositoryDidChange,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(selectedFileDidChange(_:)),
      name: RepositoryManager.selectedFileDidChange,
      object: nil
    )
  }

  // MARK: - Private — Refresh

  private func refresh() {
    let hasRepo = RepositoryManager.shared.repository != nil
    addButton.isHidden = !hasRepo
    connectButton.isHidden = hasRepo
    branchLabel.isHidden = !hasRepo
    repoNameLabel.isHidden = !hasRepo
    scrollView.isHidden = !hasRepo

    if hasRepo {
      let branch = RepositoryManager.shared.currentBranch
      branchLabel.stringValue = branch.isEmpty ? "" : "⎇ \(branch)"
      repoNameLabel.stringValue = RepositoryManager.shared.repository?.name ?? ""
    }

    outlineView.reloadData()

    // Re-select the current file if there is one
    if let selectedFile = RepositoryManager.shared.selectedFile {
      selectItemInOutlineView(selectedFile)
    }
  }

  private func selectItemInOutlineView(_ target: RepositoryFileItem) {
    func findRow(in items: [RepositoryFileItem]) -> Int? {
      for item in items {
        let row = outlineView.row(forItem: item)
        if row >= 0 { return row }
        if item.isDirectory, let children = item.children {
          if let found = findRow(in: children) { return found }
        }
      }
      return nil
    }

    if let row = findRow(in: RepositoryManager.shared.fileTree), row >= 0 {
      outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }
  }

  // MARK: - Private — File & Folder Creation

  private func parentURLForCurrentSelection() -> URL? {
    let clickedRow = outlineView.clickedRow
    guard clickedRow >= 0, let item = outlineView.item(atRow: clickedRow) as? RepositoryFileItem else {
      return RepositoryManager.shared.repository?.localPath
    }
    return item.isDirectory ? item.url : item.url.deletingLastPathComponent()
  }

  private func createNewFile(in parentURL: URL?) {
    guard let parentURL else { return }

    let alert = NSAlert()
    alert.messageText = "New File"
    alert.informativeText = "Enter the filename (e.g. notes.md):"
    alert.addButton(withTitle: "Create")
    alert.addButton(withTitle: "Cancel")

    let textField = NSTextField(frame: CGRect(x: 0, y: 0, width: 280, height: 22))
    textField.placeholderString = "filename.md"
    alert.accessoryView = textField

    guard let window = view.window else { return }
    alert.beginSheetModal(for: window) { [weak self] response in
      guard response == .alertFirstButtonReturn else { return }
      let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else { return }
      let fileURL = parentURL.appendingPathComponent(name)
      do {
        try "".write(to: fileURL, atomically: true, encoding: .utf8)
        RepositoryManager.shared.reloadFileTree()
        self?.refresh()
      } catch {
        self?.showError(error)
      }
    }
  }

  private func createNewFolder(in parentURL: URL?) {
    guard let parentURL else { return }

    let alert = NSAlert()
    alert.messageText = "New Folder"
    alert.informativeText = "Enter the folder name:"
    alert.addButton(withTitle: "Create")
    alert.addButton(withTitle: "Cancel")

    let textField = NSTextField(frame: CGRect(x: 0, y: 0, width: 280, height: 22))
    textField.placeholderString = "FolderName"
    alert.accessoryView = textField

    guard let window = view.window else { return }
    alert.beginSheetModal(for: window) { [weak self] response in
      guard response == .alertFirstButtonReturn else { return }
      let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else { return }
      let folderURL = parentURL.appendingPathComponent(name)
      do {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        RepositoryManager.shared.reloadFileTree()
        self?.refresh()
      } catch {
        self?.showError(error)
      }
    }
  }

  private func showError(_ error: Error) {
    guard let window = view.window else { return }
    let alert = NSAlert(error: error)
    alert.beginSheetModal(for: window)
  }
}

// MARK: - Actions

private extension RepositorySidebarViewController {
  @objc func showAddMenu(_ sender: NSButton) {
    let menu = NSMenu()
    menu.addItem(withTitle: "New File", action: #selector(newFileAtRoot(_:)), keyEquivalent: "")
      .target = self
    menu.addItem(withTitle: "New Folder", action: #selector(newFolderAtRoot(_:)), keyEquivalent: "")
      .target = self
    menu.popUp(positioning: nil, at: CGPoint(x: 0, y: sender.bounds.height), in: sender)
  }

  @objc func newFileAtRoot(_ sender: Any?) {
    createNewFile(in: RepositoryManager.shared.repository?.localPath)
  }

  @objc func newFolderAtRoot(_ sender: Any?) {
    createNewFolder(in: RepositoryManager.shared.repository?.localPath)
  }

  @objc func newFileHere(_ sender: Any?) {
    createNewFile(in: parentURLForCurrentSelection())
  }

  @objc func newFolderHere(_ sender: Any?) {
    createNewFolder(in: parentURLForCurrentSelection())
  }

  @objc func deleteItem(_ sender: Any?) {
    let clickedRow = outlineView.clickedRow
    guard clickedRow >= 0, let item = outlineView.item(atRow: clickedRow) as? RepositoryFileItem else { return }

    guard let window = view.window else { return }
    let alert = NSAlert()
    alert.messageText = "Delete \"\(item.name)\""
    alert.informativeText = "This action cannot be undone."
    alert.addButton(withTitle: "Delete")
    alert.addButton(withTitle: "Cancel")
    alert.buttons.first?.hasDestructiveAction = true

    alert.beginSheetModal(for: window) { [weak self] response in
      guard response == .alertFirstButtonReturn else { return }
      do {
        try FileManager.default.removeItem(at: item.url)
        if RepositoryManager.shared.selectedFile == item {
          RepositoryManager.shared.selectedFile = nil
        }
        RepositoryManager.shared.reloadFileTree()
        self?.refresh()
      } catch {
        self?.showError(error)
      }
    }
  }

  @objc func connectRepository(_ sender: Any?) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Open"
    panel.message = "Choose a folder to open in the sidebar"

    guard let window = view.window else { return }
    panel.beginSheetModal(for: window) { response in
      guard response == .OK, let url = panel.url else { return }
      let remoteURL = (try? GitService.shared.remoteURL(in: url)) ?? ""
      let repo = RepositoryModel(localPath: url, remoteURL: remoteURL)
      RepositoryManager.shared.loadRepository(repo)
    }
  }

  @objc func outlineViewClicked(_ sender: Any?) {
    let row = outlineView.clickedRow
    guard row >= 0, let item = outlineView.item(atRow: row) as? RepositoryFileItem else { return }

    if item.isDirectory {
      if outlineView.isItemExpanded(item) {
        outlineView.collapseItem(item)
      } else {
        outlineView.expandItem(item)
      }
    } else {
      RepositoryManager.shared.selectFile(item)
      fileLoadDelegate?.sidebar(self, didSelectFile: item)
    }
  }

  @objc func repositoryDidChange(_ notification: Notification) {
    refresh()
  }

  @objc func selectedFileDidChange(_ notification: Notification) {
    guard let selectedFile = RepositoryManager.shared.selectedFile else { return }
    selectItemInOutlineView(selectedFile)
  }
}

// MARK: - NSOutlineViewDataSource

extension RepositorySidebarViewController: NSOutlineViewDataSource {
  func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    if item == nil {
      return RepositoryManager.shared.fileTree.count
    }
    guard let fileItem = item as? RepositoryFileItem else { return 0 }
    return fileItem.children?.count ?? 0
  }

  func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    if item == nil {
      return RepositoryManager.shared.fileTree[index]
    }
    guard let fileItem = item as? RepositoryFileItem,
          let children = fileItem.children else {
      fatalError("Invalid item state in outline view data source")
    }
    return children[index]
  }

  func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
    guard let fileItem = item as? RepositoryFileItem else { return false }
    return fileItem.isDirectory && fileItem.children != nil
  }

  func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
    item
  }
}

// MARK: - NSOutlineViewDelegate

extension RepositorySidebarViewController: NSOutlineViewDelegate {
  func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
    guard let fileItem = item as? RepositoryFileItem else { return nil }

    let identifier = NSUserInterfaceItemIdentifier("FileCell")
    let cellView: NSTableCellView
    if let reused = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
      cellView = reused
    } else {
      cellView = NSTableCellView()
      cellView.identifier = identifier

      let imageView = NSImageView()
      imageView.translatesAutoresizingMaskIntoConstraints = false
      cellView.addSubview(imageView)
      cellView.imageView = imageView

      let textField = NSTextField()
      textField.isEditable = false
      textField.isSelectable = false
      textField.isBordered = false
      textField.drawsBackground = false
      textField.font = NSFont.systemFont(ofSize: 12)
      textField.lineBreakMode = .byTruncatingMiddle
      textField.translatesAutoresizingMaskIntoConstraints = false
      cellView.addSubview(textField)
      cellView.textField = textField

      NSLayoutConstraint.activate([
        imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 2),
        imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
        imageView.widthAnchor.constraint(equalToConstant: 16),
        imageView.heightAnchor.constraint(equalToConstant: 16),

        textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
        textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
        textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
      ])
    }

    let iconName = fileItem.isDirectory ? "folder" : "doc.text"
    cellView.imageView?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
    cellView.textField?.stringValue = fileItem.name

    return cellView
  }

  func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
    nil
  }

  func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
    guard let fileItem = item as? RepositoryFileItem else { return false }
    return !fileItem.isDirectory
  }
}
