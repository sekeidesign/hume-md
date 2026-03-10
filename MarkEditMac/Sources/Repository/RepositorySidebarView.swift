//
//  RepositorySidebarView.swift
//  MarkEditMac
//
//  SwiftUI sidebar view hosted inside NSSplitViewItem(sidebarWithViewController:)
//  for automatic Liquid Glass treatment on macOS 26.

import SwiftUI

struct RepositorySidebarView: View {
  @Environment(RepositoryManager.self)
  private var manager
  @State private var selection: RepositoryFileItem?
  // Track selection by URL so it survives reloadFileTree() creating new item objects
  @State private var selectedURL: URL?
  @State private var selectedFolderURL: URL?
  @State private var showNewFileAlert = false
  @State private var showNewFolderAlert = false
  @State private var newItemName = ""
  @State private var itemToDelete: RepositoryFileItem?

  let onFileSelected: (RepositoryFileItem) -> Void
  let onOpenFolder: () -> Void

  var body: some View {
    if manager.repository == nil {
      noRepoView
    } else {
      fileTreeView
    }
  }

  private var noRepoView: some View {
    VStack {
      Spacer()
      Button("Open Folder", action: onOpenFolder)
        .buttonStyle(.borderedProminent)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  private var fileTreeView: some View {
    List(manager.fileTree, children: \.children, selection: $selection) { item in
      Label {
        Text(item.name)
          .lineLimit(1)
          .truncationMode(.middle)
      } icon: {
        Image(systemName: item.isDirectory ? "folder" : "doc.text")
      }
      .clipped()
      .tag(item)
      .contextMenu {
        if item.isDirectory {
          Button("New File in \"\(item.name)\"") {
            selectedFolderURL = item.url
            showNewFileAlert = true
          }
          Button("New Folder in \"\(item.name)\"") {
            selectedFolderURL = item.url
            showNewFolderAlert = true
          }
          Divider()
          Button("Delete \"\(item.name)\"", role: .destructive) {
            itemToDelete = item
          }
        } else {
          Button("Delete \"\(item.name)\"", role: .destructive) {
            itemToDelete = item
          }
        }
      }
    }
    .listStyle(.sidebar)
    .scrollContentBackground(.hidden)
    .clipped()
    .animation(nil, value: manager.fileTree)
    .onChange(of: selection) { _, newItem in
      guard let newItem else { return }
      selectedURL = newItem.url
      if newItem.isDirectory {
        selectedFolderURL = newItem.url
      } else {
        selectedFolderURL = nil
        onFileSelected(newItem)
      }
    }
    .onChange(of: manager.fileTree) { _, _ in
      // After reload, restore the selection by finding items at the tracked URLs
      selection = selectedURL.flatMap { findItem(url: $0, in: manager.fileTree) }
    }
    .onAppear {
      selection = manager.selectedFile
      selectedURL = manager.selectedFile?.url
    }
    .safeAreaInset(edge: .bottom) {
      bottomBar
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        addMenu
      }
    }
    .alert(
      "Delete \"\(itemToDelete?.name ?? "")\"?",
      isPresented: Binding(
        get: { itemToDelete != nil },
        set: { if !$0 { itemToDelete = nil } }
      )
    ) {
      Button("Delete", role: .destructive) {
        if let item = itemToDelete { deleteItem(item) }
      }
      Button("Cancel", role: .cancel) { itemToDelete = nil }
    } message: {
      Text(
        itemToDelete?.isDirectory == true
          ? "This will permanently delete the folder and all its contents."
          : "This will permanently delete the file."
      )
    }
    .alert("New File", isPresented: $showNewFileAlert) {
      TextField("filename.md", text: $newItemName)
      Button("Create") { createFile() }
      Button("Cancel", role: .cancel) { newItemName = "" }
    }
    .alert("New Folder", isPresented: $showNewFolderAlert) {
      TextField("FolderName", text: $newItemName)
      Button("Create") { createFolder() }
      Button("Cancel", role: .cancel) { newItemName = "" }
    }
  }

  private var bottomBar: some View {
    HStack {
      if !manager.currentBranch.isEmpty {
        Label(manager.currentBranch, systemImage: "arrow.branch")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if let name = manager.repository?.name {
        Text(name)
          .font(.caption)
          .fontWeight(.medium)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(.bar)
  }

  /// The directory in which new items will be created — selected folder, or repo root.
  private var creationRoot: URL? {
    selectedFolderURL ?? manager.repository?.localPath
  }

  private var addMenu: some View {
    let folderName = selectedFolderURL.map { $0.lastPathComponent }
    return Menu {
      if let name = folderName {
        Section("In \"\(name)\"") {
          Button("New File") { showNewFileAlert = true }
          Button("New Folder") { showNewFolderAlert = true }
        }
        Divider()
        Section("In root") {
          Button("New File at Root") {
            selectedFolderURL = nil
            showNewFileAlert = true
          }
          Button("New Folder at Root") {
            selectedFolderURL = nil
            showNewFolderAlert = true
          }
        }
      } else {
        Button("New File") { showNewFileAlert = true }
        Button("New Folder") { showNewFolderAlert = true }
      }
    } label: {
      Image(systemName: "plus")
    }
  }

  private func createFile() {
    let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
    newItemName = ""
    guard !name.isEmpty, let root = creationRoot else { return }
    let newURL = root.appendingPathComponent(name)
    try? "".write(to: newURL, atomically: true, encoding: .utf8)
    selectedURL = newURL
    RepositoryManager.shared.reloadFileTree()
  }

  private func createFolder() {
    let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
    newItemName = ""
    guard !name.isEmpty, let root = creationRoot else { return }
    let newURL = root.appendingPathComponent(name)
    try? FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true)
    selectedURL = newURL
    selectedFolderURL = newURL
    RepositoryManager.shared.reloadFileTree()
  }

  private func deleteItem(_ item: RepositoryFileItem) {
    itemToDelete = nil
    if selectedURL == item.url || selectedURL?.path.hasPrefix(item.url.path + "/") == true {
      selectedURL = nil
      selectedFolderURL = nil
      selection = nil
    }
    try? FileManager.default.removeItem(at: item.url)
    if manager.selectedFile == item {
      manager.selectedFile = nil
    }
    RepositoryManager.shared.reloadFileTree()
  }

  /// Recursively searches a file tree for the item matching the given URL.
  private func findItem(url: URL, in items: [RepositoryFileItem]) -> RepositoryFileItem? {
    for item in items {
      if item.url == url { return item }
      if let children = item.children, let found = findItem(url: url, in: children) {
        return found
      }
    }
    return nil
  }
}
