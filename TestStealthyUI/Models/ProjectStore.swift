//
//  ProjectStore.swift
//  TestStealthyUI
//
//  Manages local persistence of projects to disk
//

import Foundation

/// Manages local persistence of projects to disk
struct ProjectStore {
    private static let fileName = "projects.json"

    /// Returns the URL for the projects file in Application Support
    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("StealthyAI", isDirectory: true)
        return appFolder.appendingPathComponent(fileName)
    }

    /// Load projects from disk
    /// - Returns: Array of projects, or empty array if file doesn't exist or can't be decoded
    static func load() -> [Project] {
        let url = fileURL

        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            decoder.dateDecodingStrategy = .iso8601

            let projects = try decoder.decode([Project].self, from: data)
            return projects
        } catch {
            print("Failed to load projects: \(error.localizedDescription)")
            return []
        }
    }

    /// Save projects to disk
    /// - Parameter projects: Array of projects to save
    static func save(_ projects: [Project]) {
        let url = fileURL

        // Ensure Application Support directory exists
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("StealthyAI", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(projects)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save projects: \(error.localizedDescription)")
        }
    }
}
