//
//  RepositoryModel.swift
//  MarkEditMac

import Foundation

struct RepositoryModel {
  let localPath: URL
  var remoteURL: String

  var name: String { localPath.lastPathComponent }
}
