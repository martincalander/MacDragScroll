import Foundation

enum PreferenceInputFuzzer {
    static func exercise(_ data: Data) {
        _ = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)

        let text = String(decoding: data.prefix(4096), as: UTF8.self)
        _ = normalizedBundleIdentifierCandidate(text)
        _ = normalizedURLCandidate(text)
        _ = booleanLikeValue(text)
    }

    private static func normalizedBundleIdentifierCandidate(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty, trimmed.count <= 255 else {
            return nil
        }

        let allowedPunctuation = Set<UnicodeScalar>([".", "-", "_"])
        guard trimmed.unicodeScalars.allSatisfy({ scalar in
            CharacterSet.alphanumerics.contains(scalar) || allowedPunctuation.contains(scalar)
        }) else {
            return nil
        }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else {
            return nil
        }

        guard parts.allSatisfy({ part in
            !part.isEmpty && !part.hasPrefix("-") && !part.hasSuffix("-")
        }) else {
            return nil
        }

        return trimmed.lowercased()
    }

    private static func normalizedURLCandidate(_ input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 2048 else {
            return nil
        }
        return URL(string: trimmed)
    }

    private static func booleanLikeValue(_ input: String) -> Bool? {
        switch input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "enabled", "on":
            return true
        case "0", "false", "no", "disabled", "off":
            return false
        default:
            return nil
        }
    }
}

#if FUZZING
@_cdecl("LLVMFuzzerTestOneInput")
public func LLVMFuzzerTestOneInput(_ dataPointer: UnsafePointer<UInt8>?, _ size: Int) -> Int32 {
    guard let dataPointer, size >= 0 else {
        return 0
    }

    let bytes = UnsafeBufferPointer(start: dataPointer, count: size)
    PreferenceInputFuzzer.exercise(Data(buffer: bytes))
    return 0
}
#endif
