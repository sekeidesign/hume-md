//
//  EditorWindowController.swift
//  MarkEditMac
//
//  Created by cyan on 12/12/22.
//

import AppKit
import SwiftUI

final class EditorWindowController: NSWindowController, NSWindowDelegate {
  var autosavedFrame: CGRect?
  var needsUpdateFocus = false

  private var _editorViewController: EditorViewController?

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    shouldCascadeWindows = true
  }

  override var contentViewController: NSViewController? {
    get { super.contentViewController }
    set {
      // When makeWindowControllers() sets the EditorViewController, wrap it in a split view
      if let editorVC = newValue as? EditorViewController {
        _editorViewController = editorVC

        let sidebarView = RepositorySidebarView(
          onFileSelected: { [weak editorVC] file in
            editorVC?.loadRepositoryFile(file)
          },
          onOpenFolder: { [weak self] in
            self?.openFolderPanel()
          }
        )
        .environment(RepositoryManager.shared)

        let sidebarHostingVC = NSHostingController(rootView: sidebarView)
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarHostingVC)
        sidebarItem.minimumThickness = 280
        sidebarItem.maximumThickness = 480
        sidebarItem.preferredThicknessFraction = 0.25
        sidebarItem.canCollapse = true

        let editorItem = NSSplitViewItem(viewController: editorVC)
        editorItem.minimumThickness = 400

        let splitVC = NSSplitViewController()
        splitVC.addSplitViewItem(sidebarItem)
        splitVC.addSplitViewItem(editorItem)

        super.contentViewController = splitVC
      } else {
        super.contentViewController = newValue
      }
    }
  }

  override func windowDidLoad() {
    super.windowDidLoad()
    window?.minSize = CGSize(width: 640, height: 0)
    window?.backgroundColor = .controlBackgroundColor

    windowFrameAutosaveName = "Editor"
    window?.setFrameUsingName(windowFrameAutosaveName)
    saveWindowRect()
  }

  func windowDidBecomeMain(_ notification: Notification) {
    NSApplication.shared.closeOpenPanels()
  }

  func windowDidResignMain(_ notification: Notification) {
    if AppPreferences.Editor.showLineNumbers {
      // In theory, this is not indeed, but we've seen wrong state without this
      editorViewController?.bridge.core.handleMouseExited(clientX: 0, clientY: 0)
    }
  }

  func windowDidBecomeKey(_ notification: Notification) {
    if needsUpdateFocus {
      editorViewController?.refreshEditFocus()
      needsUpdateFocus = false
    }

    // The shared "field editor" tends to hold focus,
    // manually resign the focus to ensure cmd-f responds correctly.
    for editor in EditorReusePool.shared.viewControllers() where editor !== editorViewController {
      editor.resignFindPanelFocus()
    }

    // The main menu is a singleton, we need to update the menu items for the active editor
    editorViewController?.resetUserDefinedMenuItems()
  }

  func windowDidResignKey(_ notification: Notification) {
    needsUpdateFocus = editorViewController?.webView.isFirstResponder == true
    editorViewController?.cancelCompletion()
    editorViewController?.bridge.core.handleFocusLost()
  }

  func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
    // By default, zooming a window doesn't clear the tiling state,
    // this is different from moving or resizing the window.
    //
    // We manually clear the tiling state after a short delay to keep the behavior consistent.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      guard let autosaveName = self?.windowFrameAutosaveName else {
        return
      }

      UserDefaults.resetTilingState(for: "NSWindow Frame \(autosaveName)")
    }

    return true
  }

  func windowDidResize(_ notification: Notification) {
    window?.saveFrame(usingName: windowFrameAutosaveName)
    editorViewController?.cancelCompletion()
  }

  func windowWillClose(_ notification: Notification) {
    editorViewController?.clearEditor()
  }
}

// MARK: - Internal

extension EditorWindowController {
  func openFolderPanel() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Open"
    panel.message = "Choose a folder to open in the sidebar"
    guard let window else { return }
    panel.beginSheetModal(for: window) { response in
      guard response == .OK, let url = panel.url else { return }
      let remoteURL = (try? GitService.shared.remoteURL(in: url)) ?? ""
      let repo = RepositoryModel(localPath: url, remoteURL: remoteURL)
      RepositoryManager.shared.loadRepository(repo)
    }
  }
}

// MARK: - Private

private extension EditorWindowController {
  var editorViewController: EditorViewController? {
    _editorViewController
  }

  func saveWindowRect() {
  #if DEBUG
    guard ProcessInfo.processInfo.environment["DEBUG_TAKING_SCREENSHOTS"] != "YES" else {
      return
    }
  #endif

    // Editor view controllers are created without having a window (for pre-loading),
    // this is used for restoring the autosaved window frame.
    //
    // Unfortunately, we need to manually do the window cascading.
    if let window, NSApp.windows.filter({ $0 is EditorWindow }).count > 1 {
      autosavedFrame = window.cascadeRect(from: window.frame)
    } else {
      autosavedFrame = window?.frame
    }
  }
}
