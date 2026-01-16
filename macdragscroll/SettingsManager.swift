//
//  SettingsManager.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-16.
//

import Foundation

class SettingsManager {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    private let isEnabledKey = "isEnabled"
    
    var isEnabled: Bool {
        get { defaults.bool(forKey: isEnabledKey) }
        set { defaults.set(newValue, forKey: isEnabledKey) }
    }
    
    private init() {
        defaults.register(defaults: [isEnabledKey: true])
    }
}
