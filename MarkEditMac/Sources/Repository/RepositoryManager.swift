//
//  RepositoryManager.swift
//  MarkEditMac
//
//  Singleton that tracks repository state and notifies via NotificationCenter.

import Foundation

@MainActor
@Observable
final class RepositoryManager {
  static let shared = RepositoryManager()

  // MARK: - Notification Names

  static let repositoryDidChange = Notification.Name("RepositoryDidChange")
  static let selectedFileDidChange = Notification.Name("SelectedFileDidChange")

  // MARK: - State

  var repository: RepositoryModel? {
    didSet {
      if let repo = repository {
        UserDefaults.standard.set(repo.localPath.path, forKey: "repository.localPath")
        UserDefaults.standard.set(repo.remoteURL, forKey: "repository.remoteURL")
      } else {
        UserDefaults.standard.removeObject(forKey: "repository.localPath")
        UserDefaults.standard.removeObject(forKey: "repository.remoteURL")
      }
    }
  }

  var fileTree: [RepositoryFileItem] = []
  var selectedFile: RepositoryFileItem?
  var isDirty = false
  var currentBranch = ""

  // MARK: - Init

  private init() {
    restoreFromUserDefaults()
  }

  // MARK: - Public Methods

  func loadRepository(_ repo: RepositoryModel) {
    repository = repo
    reloadFileTree()
    loadCurrentBranch()
    NotificationCenter.default.post(name: Self.repositoryDidChange, object: self)
  }

  func reloadFileTree() {
    guard let localPath = repository?.localPath else {
      fileTree = []
      return
    }
    fileTree = FileService.shared.loadFiles(from: localPath)
  }

  func selectFile(_ file: RepositoryFileItem) {
    isDirty = false
    selectedFile = file
    NotificationCenter.default.post(name: Self.selectedFileDidChange, object: self)
  }

  func saveCurrentFile(text: String) {
    guard let file = selectedFile else { return }
    do {
      try text.write(to: file.url, atomically: true, encoding: .utf8)
      isDirty = false
    } catch {
      // Writing failed — leave isDirty unchanged
    }
  }

  // MARK: - Private

  private func restoreFromUserDefaults() {
    guard
      let pathString = UserDefaults.standard.string(forKey: "repository.localPath"),
      !pathString.isEmpty
    else { return }

    let localPath = URL(fileURLWithPath: pathString)
    let remoteURL = UserDefaults.standard.string(forKey: "repository.remoteURL") ?? ""
    let repo = RepositoryModel(localPath: localPath, remoteURL: remoteURL)
    repository = repo
    reloadFileTree()
    loadCurrentBranch()
  }

  func listBranches() async throws -> [String] {
    guard let localPath = repository?.localPath else { return [] }
    return try await GitService.shared.listBranches(in: localPath)
  }

  func checkoutBranch(_ branch: String) async throws {
    guard let localPath = repository?.localPath else { return }
    try await GitService.shared.checkoutBranch(branch, in: localPath)
    currentBranch = branch
  }

  func createBranch(named name: String) async throws {
    guard let localPath = repository?.localPath else { return }
    try await GitService.shared.createBranch(named: name, in: localPath)
    currentBranch = name
  }

  private func loadCurrentBranch() {
    guard let localPath = repository?.localPath else { return }
    Task {
      if let branch = try? await GitService.shared.currentBranch(in: localPath) {
        self.currentBranch = branch
      }
    }
  }
}
