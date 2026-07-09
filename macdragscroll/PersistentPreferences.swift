//
//  PersistentPreferences.swift
//  macdragscroll
//
//  Created by OpenAI Codex on 2026-07-09.
//

import Foundation

enum PersistentPreferences {
    static let domainIdentifier = "com.martincalander.macdragscroll"

    static let userDefaults: UserDefaults = UserDefaults(suiteName: domainIdentifier) ?? .standard

    static var preferencesFilePath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(domainIdentifier).plist")
            .path
    }
}
