//
//  EditorViewController+Repository.swift
//  MarkEditMac

import AppKit

extension EditorViewController: RepositorySidebarDelegate {
  func sidebar(_ sidebar: RepositorySidebarViewController, didSelectFile file: RepositoryFileItem) {
    loadRepositoryFile(file)
  }

  func loadRepositoryFile(_ file: RepositoryFileItem) {
    setUpEmptyStateIfNeeded()
    saveCurrentRepositoryFile()

    do {
      let content = try String(contentsOf: file.url, encoding: .utf8)
      RepositoryManager.shared.selectedFile = file
      updateEmptyState()
      if hasFinishedLoading {
        bridge.core.resetEditor(text: content, completion: nil)
      }
    } catch {
      let alert = NSAlert()
      alert.messageText = "Could Not Open File"
      alert.informativeText = error.localizedDescription
      if let window = view.window {
        alert.beginSheetModal(for: window)
      }
    }
  }

  func saveCurrentRepositoryFile() {
    guard RepositoryManager.shared.selectedFile != nil,
          RepositoryManager.shared.isDirty else { return }
    Task {
      if let text = await editorText {
        RepositoryManager.shared.saveCurrentFile(text: text)
      }
    }
  }
}
