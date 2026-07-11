//
//  AppLocalization.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-07-08.
//

import Foundation

final class AppLocalization {
    static let shared = AppLocalization()

    private var bundlesByLanguageCode: [String: Bundle] = [:]
    private var missingLanguageCodes: Set<String> = []

    private init() {}

    func localizedString(_ key: String, value: String, comment: String) -> String {
        guard let languageCode = SettingsManager.shared.appLanguage.lprojCode,
              let bundle = localizedBundle(for: languageCode) else {
            return Bundle.main.localizedString(forKey: key, value: value, table: nil)
        }

        return bundle.localizedString(forKey: key, value: value, table: nil)
    }

    private func localizedBundle(for languageCode: String) -> Bundle? {
        if let bundle = bundlesByLanguageCode[languageCode] {
            return bundle
        }

        guard !missingLanguageCodes.contains(languageCode),
              let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            missingLanguageCodes.insert(languageCode)
            return nil
        }

        bundlesByLanguageCode[languageCode] = bundle
        return bundle
    }
}
