//
//  RepositoryFileItem.swift
//  MarkEditMac

import Foundation

final class RepositoryFileItem {
  let id = UUID()
  let name: String
  let url: URL
  let isDirectory: Bool
  var children: [RepositoryFileItem]?

  init(url: URL, isDirectory: Bool, children: [RepositoryFileItem]? = nil) {
    self.url = url
    self.name = url.lastPathComponent
    self.isDirectory = isDirectory
    self.children = children
  }
}

extension RepositoryFileItem: Identifiable {}

extension RepositoryFileItem: Equatable {
  static func == (lhs: RepositoryFileItem, rhs: RepositoryFileItem) -> Bool { lhs.id == rhs.id }
}

extension RepositoryFileItem: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
