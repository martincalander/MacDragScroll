//
//  AppLocalization.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-07-08.
//

import Foundation

final class AppLocalization {
    static let shared = AppLocalization()

    private init() {}

    func localizedString(_ key: String, value: String, comment: String) -> String {
        guard let languageCode = SettingsManager.shared.appLanguage.lprojCode,
              let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main.localizedString(forKey: key, value: value, table: nil)
        }

        return bundle.localizedString(forKey: key, value: value, table: nil)
    }
}
