//
//  GitService.swift
//  MarkEditMac
//
//  Shells out to `git` via Process for repository operations.

import Foundation

final class GitService {
  static let shared = GitService()

  private init() {}

  // MARK: - Public API

  func clone(url: String, to localPath: URL) async throws {
    _ = try await execute(["clone", url, localPath.path])
  }

  func addAll(in repoPath: URL) async throws {
    _ = try await execute(["add", "--all"], workingDirectory: repoPath)
  }

  func commit(message: String, in repoPath: URL) async throws {
    _ = try await execute(["commit", "-m", message], workingDirectory: repoPath)
  }

  func push(in repoPath: URL) async throws {
    _ = try await execute(["push"], workingDirectory: repoPath)
  }

  func currentBranch(in repoPath: URL) async throws -> String {
    let output = try await execute(["rev-parse", "--abbrev-ref", "HEAD"], workingDirectory: repoPath)
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func listBranches(in repoPath: URL) async throws -> [String] {
    let output = try await execute(["branch", "--list", "--format=%(refname:short)"], workingDirectory: repoPath)
    return output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
  }

  func checkoutBranch(_ branch: String, in repoPath: URL) async throws {
    _ = try await execute(["checkout", branch], workingDirectory: repoPath)
  }

  func createBranch(named name: String, in repoPath: URL) async throws {
    _ = try await execute(["checkout", "-b", name], workingDirectory: repoPath)
  }

  /// Synchronous version for use in NSOpenPanel context.
  func remoteURL(in repoPath: URL) throws -> String {
    let output = try executeSync(["remote", "get-url", "origin"], workingDirectory: repoPath)
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

// MARK: - Private

private extension GitService {
  @discardableResult
  func execute(_ arguments: [String], workingDirectory: URL? = nil) async throws -> String {
    let args = arguments
    let dir = workingDirectory
    return try await Task.detached(priority: .userInitiated) {
      try GitService.shared.executeSync(args, workingDirectory: dir)
    }.value
  }

  // /usr/bin/git is an xcrun wrapper that refuses to run inside the App Sandbox.
  // Look for the real git binary at known locations instead.
  static let executableURL: URL = {
    let candidates = [
      "/opt/homebrew/bin/git",  // Apple Silicon Homebrew
      "/usr/local/bin/git",     // Intel Homebrew
      "/Applications/Xcode.app/Contents/Developer/usr/bin/git",  // Xcode bundled
    ]
    for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
      return URL(fileURLWithPath: path)
    }
    return URL(fileURLWithPath: "/usr/bin/git")
  }()

  @discardableResult
  func executeSync(_ arguments: [String], workingDirectory: URL? = nil) throws -> String {
    let process = Process()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()

    process.executableURL = Self.executableURL
    process.arguments = arguments
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    if let workingDirectory {
      process.currentDirectoryURL = workingDirectory
    }

    try process.run()
    process.waitUntilExit()

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

    guard process.terminationStatus == 0 else {
      let message = stderr.isEmpty ? "git \(arguments.joined(separator: " ")) failed with exit code \(process.terminationStatus)" : stderr.trimmingCharacters(in: .whitespacesAndNewlines)
      throw GitError.commandFailed(message)
    }

    return stdout
  }
}

// MARK: - GitError

enum GitError: LocalizedError {
  case commandFailed(String)

  var errorDescription: String? {
    switch self {
    case .commandFailed(let message):
      return message
    }
  }
}
