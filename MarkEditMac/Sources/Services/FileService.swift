//
//  FileService.swift
//  MarkEditMac
//
//  Recursive file tree builder for .md/.mdx files.

import Foundation

final class FileService {
  static let shared = FileService()

  private init() {}

  private let allowedExtensions: Set<String> = ["md", "mdx"]
  private let ignoredNames: Set<String> = [
    ".git", "node_modules", ".next", "dist", "build",
    ".DS_Store", ".svn", ".hg",
  ]

  func loadFiles(from rootURL: URL) -> [RepositoryFileItem] {
    buildTree(at: rootURL)
  }

  private func buildTree(at url: URL) -> [RepositoryFileItem] {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(
      at: url,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else { return [] }

    var items: [RepositoryFileItem] = []
    for itemURL in contents {
      let name = itemURL.lastPathComponent
      guard !ignoredNames.contains(name) else { continue }
      let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
      if isDir {
        let children = buildTree(at: itemURL)
        items.append(RepositoryFileItem(url: itemURL, isDirectory: true, children: children.isEmpty ? nil : children))
      } else if allowedExtensions.contains(itemURL.pathExtension.lowercased()) {
        items.append(RepositoryFileItem(url: itemURL, isDirectory: false))
      }
    }
    return items.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }
}
