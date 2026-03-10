//
//  EditorViewController+Toolbar.swift
//  MarkEditMac
//
//  Created by cyan on 1/13/23.
//

import AppKit
import MarkEditKit
import SwiftUI

extension EditorViewController {
  var tableOfContentsMenuButton: NSPopUpButton? {
    view.window?.popUpButton(with: Constants.tableOfContentsMenuIdentifier)
  }

  var statisticsSourceView: NSView? {
    // Present the popover relative to the toolbar item
    view.window?.toolbarButton(with: statisticsItem.itemIdentifier) ??
    // Present the popover relative to the document title view
    view.window?.toolbarTitleView
  }

  private enum Constants {
    static let tableOfContentsMenuIdentifier = NSUserInterfaceItemIdentifier("tableOfContentsMenu")
    static let tableOfContentsMinimumWidth: Double = 160

    @MainActor static let normalizedButtonSize: Double? = {
      if AppDesign.modernStyle {
        // The issue seems fixed with the Liquid Glass design
        return nil
      }

      // "bold" icon looks bigger than expected, fix it
      return 15
    }()
  }

  func updateToolbarItemMenus(_ menu: NSMenu) {
    if menu.identifier == Constants.tableOfContentsMenuIdentifier {
      updateTableOfContentsMenu(menu)
    }
  }

  func showTableOfContentsMenu() {
    bridge.core.handleFocusLost()
    presentedPopover?.close()

    // Pop up the menu relative to the toolbar item
    if let tableOfContentsMenuButton {
      return RunLoop.main.perform(inModes: [.default, .eventTracking]) {
        tableOfContentsMenuButton.performClick(nil)
      }
    }

    // Pop up the menu relative to the document title view
    if let menu = (tableOfContentsItem as? NSMenuToolbarItem)?.menu,
       let sourceView = view.window?.toolbarTitleView {
      menu.popUp(
        positioning: nil,
        at: CGPoint(x: sourceView.bounds.minX, y: sourceView.bounds.maxY + 15),
        in: sourceView
      )
      return
    }
  }

  func customItem(with identifier: NSToolbarItem.Identifier) -> CustomToolbarItem? {
    AppRuntimeConfig.customToolbarItems.first {
      $0.identifier.rawValue == identifier.rawValue
    }
  }
}

// MARK: - NSToolbarDelegate

extension EditorViewController: NSToolbarDelegate {
  func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
    let item: NSToolbarItem? = {
      switch itemIdentifier {
      case .tableOfContents: return tableOfContentsItem
      case .formatHeaders: return formatHeadersItem
      case .toggleBold: return toggleBoldItem
      case .toggleItalic: return toggleItalicItem
      case .toggleStrikethrough: return toggleStrikethroughItem
      case .insertLink: return insertLinkItem
      case .insertImage: return insertImageItem
      case .toggleList: return toggleListItem
      case .toggleBlockquote: return toggleBlockquoteItem
      case .horizontalRule: return horizontalRuleItem
      case .insertTable: return insertTableItem
      case .insertCode: return insertCodeItem
      case .textFormat: return textFormatItem
      case .statistics: return statisticsItem
      case .shareDocument: return shareDocumentItem
      case .copyPandocCommand: return copyPandocCommandItem
      case .writingTools: return writingToolsItem
      case .connectRepository: return connectRepositoryItem
      case .publish: return publishItem
      case .branchLabel: return branchLabelItem
      default:
        if let customItem = customItem(with: itemIdentifier) {
          return .with(identifier: itemIdentifier, customItem: customItem)
        }

        return nil
      }
    }()

    if let item, item.toolTip == nil {
      if let shortcutHint = item.shortcutHint {
        item.toolTip = "\(item.label) (\(shortcutHint))"
      } else {
        item.toolTip = item.label
      }
    }

    item?.isBordered = true
    return item
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    NSToolbarItem.Identifier.defaultItems
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    NSToolbarItem.Identifier.allItems + AppRuntimeConfig.customToolbarItems.map {
      $0.identifier
    }
  }
}

// MARK: - NSToolbarItemValidation

extension EditorViewController: NSToolbarItemValidation {
  func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
    return true
  }
}

// MARK: - NSSharingServicePickerToolbarItemDelegate

extension EditorViewController: NSSharingServicePickerToolbarItemDelegate {
  func items(for pickerToolbarItem: NSSharingServicePickerToolbarItem) -> [Any] {
    guard let document else {
      return []
    }

    return [document]
  }
}

// MARK: - Private

private extension EditorViewController {
  var tableOfContentsItem: NSToolbarItem {
    let menu = NSMenu()
    menu.delegate = self
    menu.identifier = Constants.tableOfContentsMenuIdentifier
    menu.minimumWidth = Constants.tableOfContentsMinimumWidth

    let label = NSMenuItem(title: Localized.Toolbar.tableOfContents, action: nil, keyEquivalent: "")
    label.isEnabled = false

    menu.items = [label, .separator()]
    menu.autoenablesItems = false

    return .with(identifier: .tableOfContents, menu: menu)
  }

  var formatHeadersItem: NSToolbarItem {
    .with(identifier: .formatHeaders, menu: NSApp.appDelegate?.formatHeadersMenu?.copiedMenu)
  }

  var toggleBoldItem: NSToolbarItem {
    .with(identifier: .toggleBold, iconSize: Constants.normalizedButtonSize) { [weak self] in
      self?.toggleBold(nil)
    }
  }

  var toggleItalicItem: NSToolbarItem {
    .with(identifier: .toggleItalic, iconSize: Constants.normalizedButtonSize) { [weak self] in
      self?.toggleItalic(nil)
    }
  }

  var toggleStrikethroughItem: NSToolbarItem {
    .with(identifier: .toggleStrikethrough, iconSize: Constants.normalizedButtonSize) { [weak self] in
      self?.toggleStrikethrough(nil)
    }
  }

  var insertLinkItem: NSToolbarItem {
    .with(identifier: .insertLink) { [weak self] in
      self?.insertLink(nil)
    }
  }

  var insertImageItem: NSToolbarItem {
    .with(identifier: .insertImage) { [weak self] in
      self?.insertImage(nil)
    }
  }

  var toggleListItem: NSToolbarItem {
    let menu = NSMenu()
    menu.items = [
      NSApp.appDelegate?.formatBulletItem,
      NSApp.appDelegate?.formatNumberingItem,
      NSApp.appDelegate?.formatTodoItem,
    ].compactMap { $0?.copiedItem }

    return .with(identifier: .toggleList, menu: menu)
  }

  var toggleBlockquoteItem: NSToolbarItem {
    .with(identifier: .toggleBlockquote) { [weak self] in
      self?.toggleBlockquote(nil)
    }
  }

  var horizontalRuleItem: NSToolbarItem {
    .with(identifier: .horizontalRule) { [weak self] in
      self?.insertHorizontalRule(nil)
    }
  }

  var insertTableItem: NSToolbarItem {
    .with(identifier: .insertTable) { [weak self] in
      self?.insertTable(nil)
    }
  }

  var insertCodeItem: NSToolbarItem {
    let menu = NSMenu()
    menu.items = [
      NSApp.appDelegate?.formatCodeItem,
      NSApp.appDelegate?.formatCodeBlockItem,
      NSApp.appDelegate?.formatMathItem,
      NSApp.appDelegate?.formatMathBlockItem,
    ].compactMap { $0?.copiedItem }

    return .with(identifier: .insertCode, menu: menu)
  }

  var textFormatItem: NSToolbarItem {
    .with(identifier: .textFormat, menu: NSApp.appDelegate?.textFormatMenu?.copiedMenu)
  }

  var statisticsItem: NSToolbarItem {
    .with(identifier: .statistics) { [weak self] in
      self?.toggleStatisticsPopover(sourceView: self?.statisticsSourceView)
    }
  }

  var shareDocumentItem: NSToolbarItem {
    let item = NSSharingServicePickerToolbarItem(itemIdentifier: .shareDocument)
    item.toolTip = Localized.Toolbar.shareDocument
    item.image = NSImage(systemSymbolName: Icons.squareAndArrowUp, accessibilityDescription: Localized.Toolbar.shareDocument)
    item.delegate = self
    return item
  }

  var copyPandocCommandItem: NSToolbarItem {
    .with(identifier: .copyPandocCommand, menu: NSApp.appDelegate?.copyPandocCommandMenu?.copiedMenu)
  }

  var writingToolsItem: NSToolbarItem? {
    if #available(macOS 15.1, *), let menu = systemWritingToolsMenu {
      return .with(identifier: .writingTools, menu: menu.copiedMenu)
    } else {
      return nil
    }
  }

  var connectRepositoryItem: NSToolbarItem {
    .with(identifier: .connectRepository) { [weak self] in
      (self?.view.window?.windowController as? EditorWindowController)?.openFolderPanel()
    }
  }

  var publishItem: NSToolbarItem {
    let item = NSToolbarItem(itemIdentifier: .publish)
    item.label = "Push"
    item.view = NSHostingView(
      rootView: PushButtonView { [weak self] in
        guard RepositoryManager.shared.repository != nil else { return }
        let vc = PublishViewController()
        self?.presentAsSheet(vc)
      }.environment(RepositoryManager.shared)
    )
    return item
  }

  var branchLabelItem: NSToolbarItem {
    let item = NSToolbarItem(itemIdentifier: .branchLabel)
    item.label = "Branch"
    let hostingView = NSHostingView(
      rootView: BranchLabelView().environment(RepositoryManager.shared)
    )
    hostingView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    hostingView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    item.view = hostingView
    return item
  }

  func updateTableOfContentsMenu(_ menu: NSMenu) {
    // Remove existing items, the first two are placeholders that we want to keep
    for (index, item) in menu.items.enumerated() where index > 1 {
      menu.removeItem(item)
    }

    Task {
      let tableOfContents = await tableOfContents
      let baseLevel = tableOfContents?.map { $0.level }.min() ?? 1

      tableOfContents?.forEach { info in
        let title = String(repeating: " ", count: (info.level - baseLevel) * 2) + info.title
        let item = menu.addItem(withTitle: title, action: #selector(self.gotoHeader(_:)))
        item.representedObject = info
        item.setAccessibilityLabel(title)
        item.setAccessibilityValue(info.level)

        if info.selected {
          item.setAccessibilityHelp(Localized.General.selected)
        }

        let fontSize = 15.0 - min(3, Double(info.level))
        let attributedTitle = NSMutableAttributedString()

        attributedTitle.append(NSAttributedString(string: info.selected ? "‣" : " ", attributes: [
          .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium),
        ]))

        attributedTitle.append(NSAttributedString(string: " \(title)", attributes: [
          .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
        ]))

        item.attributedTitle = attributedTitle
        menu.addItem(.separator())
      }
    }
  }

  @objc func gotoHeader(_ sender: NSMenuItem) {
    guard let headingInfo = sender.representedObject as? HeadingInfo else {
      Logger.assertFail("Failed to get HeadingInfo from sender: \(sender)")
      return
    }

    startTextEditing()
    bridge.toc.gotoHeader(headingInfo: headingInfo)
  }
}

// MARK: - SwiftUI Toolbar Views

private struct PushButtonView: View {
  @Environment(RepositoryManager.self)
  private var manager

  let action: () -> Void

  var body: some View {
    Button(role: .confirm, action: action) {
      Label("Push", systemImage: "arrow.up")
        .labelStyle(.titleAndIcon)
    }
    .buttonStyle(.glassProminent)
    .disabled(manager.repository == nil)
  }
}

private struct BranchLabelView: View {
  @Environment(RepositoryManager.self)
  private var manager
  @State private var showPopover = false

  var body: some View {
    Button {
      showPopover = true
    } label: {
      Text("⎇  \(manager.currentBranch.isEmpty ? "No branch" : manager.currentBranch)")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .fixedSize()
    }
    .buttonStyle(.plain)
    .popover(isPresented: $showPopover, arrowEdge: .bottom) {
      BranchPopoverView(isPresented: $showPopover)
        .environment(manager)
    }
  }
}

private struct BranchPopoverView: View {
  @Environment(RepositoryManager.self)
  private var manager
  @Binding var isPresented: Bool
  @State private var branches: [String] = []
  @State private var showNewBranchField = false
  @State private var newBranchName = ""
  @State private var isLoading = false
  @State private var errorMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Switch Branch")
        .font(.headline)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)

      Divider()

      if isLoading {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(branches, id: \.self) { branch in
              branchRow(branch)
            }
          }
        }
        .frame(maxHeight: 600)
      }

      Divider()

      if showNewBranchField {
        HStack {
          TextField("branch-name", text: $newBranchName)
            .textFieldStyle(.roundedBorder)
            .onSubmit { createBranch() }
          Button("Create") { createBranch() }
            .disabled(newBranchName.trimmingCharacters(in: .whitespaces).isEmpty)
          Button("Cancel") {
            showNewBranchField = false
            newBranchName = ""
          }
          .foregroundStyle(.secondary)
        }
        .padding(12)
      } else {
        Button {
          showNewBranchField = true
        } label: {
          Label("New Branch", systemImage: "plus")
        }
        .padding(12)
      }

      if let error = errorMessage {
        Text(error)
          .font(.caption)
          .foregroundStyle(.red)
          .padding(.horizontal, 12)
          .padding(.bottom, 8)
      }
    }
    .frame(width: 240)
    .task { await loadBranches() }
  }

  private func branchRow(_ branch: String) -> some View {
    let isCurrent = branch == manager.currentBranch
    return Button {
      guard !isCurrent else { return }
      Task { await checkout(branch) }
    } label: {
      HStack {
        Image(systemName: "arrow.branch")
          .frame(width: 16)
          .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
        Text(branch)
          .font(.system(.body, design: .monospaced, weight: isCurrent ? .semibold : .regular))
        Spacer()
        if isCurrent {
          Image(systemName: "checkmark")
            .foregroundStyle(Color.accentColor)
        }
      }
      .contentShape(Rectangle())
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
    }
    .buttonStyle(.plain)
    .background(isCurrent ? Color.accentColor.opacity(0.1) : .clear)
  }

  private func loadBranches() async {
    isLoading = true
    branches = (try? await manager.listBranches()) ?? []
    isLoading = false
  }

  private func checkout(_ branch: String) async {
    do {
      try await manager.checkoutBranch(branch)
      isPresented = false
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func createBranch() {
    let name = newBranchName.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return }
    newBranchName = ""
    showNewBranchField = false
    Task {
      do {
        try await manager.createBranch(named: name)
        await loadBranches()
        isPresented = false
      } catch {
        errorMessage = error.localizedDescription
        showNewBranchField = true
      }
    }
  }
}
