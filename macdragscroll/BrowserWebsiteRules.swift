//
//  BrowserWebsiteRules.swift
//  macdragscroll
//
//  Website matching and bounded, host-only browser page resolution.
//

import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

nonisolated enum BrowserApplication: String, CaseIterable, Sendable {
    case safari = "com.apple.Safari"
    case googleChrome = "com.google.Chrome"

    static func classify(bundleIdentifier: String?) -> BrowserApplication? {
        guard let bundleIdentifier else { return nil }
        return BrowserApplication(rawValue: bundleIdentifier)
    }
}

nonisolated struct BrowserPageContext: Equatable, Hashable, Sendable {
    let host: String

    init?(host: String) {
        guard let normalizedHost = WebsiteHost.normalized(host) else { return nil }
        self.host = normalizedHost
    }
}

nonisolated enum WebsiteHost {
    private static let maximumRuleInputUTF8Length = 2_048
    private static let maximumPageReferenceUTF8Length = 16_384

    static func normalized(_ rawValue: String) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.utf8.count <= maximumRuleInputUTF8Length else {
            return nil
        }

        if let address = normalizedIPAddress(value) {
            return address
        }

        if let components = URLComponents(string: value), components.scheme != nil {
            guard case .httpHost(let host) = pageReference(from: value) else {
                return nil
            }
            return host
        }

        return normalizedHostLiteral(value)
    }

    static func matches(
        host rawHost: String,
        rule rawRule: String,
        includeSubdomains: Bool = true
    ) -> Bool {
        guard let host = normalized(rawHost),
              let rule = normalized(rawRule) else {
            return false
        }

        guard host != rule else { return true }
        guard includeSubdomains,
              normalizedIPAddress(host) == nil,
              normalizedIPAddress(rule) == nil else {
            return false
        }

        return host.hasSuffix(".\(rule)")
    }

    fileprivate enum PageReference: Equatable, Hashable {
        case httpHost(String)
        case nonHTTPContent
        case malformed
    }

    fileprivate static func pageReference(from rawValue: String) -> PageReference {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .nonHTTPContent }
        guard value.utf8.count <= maximumPageReferenceUTF8Length else {
            return .malformed
        }
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased() else {
            return .malformed
        }

        guard scheme == "http" || scheme == "https" else {
            return .nonHTTPContent
        }

        guard let url = components.url,
              let rawHost = url.host,
              let host = normalizedHostLiteral(rawHost) else {
            return .malformed
        }

        return .httpHost(host)
    }

    fileprivate static func pageReference(from url: URL) -> PageReference {
        guard let scheme = url.scheme?.lowercased() else { return .malformed }
        guard scheme == "http" || scheme == "https" else {
            return .nonHTTPContent
        }
        guard let rawHost = url.host,
              let host = normalizedHostLiteral(rawHost) else {
            return .malformed
        }
        return .httpHost(host)
    }

    private static func normalizedHostLiteral(_ rawHost: String) -> String? {
        var candidate = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return nil }

        if candidate.first == "[", candidate.last == "]" {
            candidate.removeFirst()
            candidate.removeLast()
        }

        if let address = normalizedIPAddress(candidate) {
            return address
        }

        if candidate.hasSuffix(".") {
            candidate.removeLast()
        }

        guard !candidate.isEmpty,
              !candidate.hasPrefix("."),
              !candidate.hasSuffix("."),
              !candidate.contains("..") else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = candidate

        guard let encodedHost = components.url?.host else { return nil }
        let host = encodedHost.lowercased()
        guard host.utf8.count <= 253 else { return nil }

        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty else { return nil }

        for label in labels {
            guard !label.isEmpty,
                  label.utf8.count <= 63,
                  let first = label.utf8.first,
                  let last = label.utf8.last,
                  isASCIILetterOrDigit(first),
                  isASCIILetterOrDigit(last),
                  label.utf8.allSatisfy({ byte in
                      isASCIILetterOrDigit(byte) || byte == 45
                  }) else {
                return nil
            }
        }

        return host
    }

    private static func normalizedIPAddress(_ rawValue: String) -> String? {
        var candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.first == "[", candidate.last == "]" {
            candidate.removeFirst()
            candidate.removeLast()
        }
        guard !candidate.isEmpty else { return nil }

        var ipv4 = in_addr()
        if candidate.withCString({ inet_pton(AF_INET, $0, &ipv4) }) == 1 {
            var output = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &ipv4, &output, socklen_t(output.count)) != nil else {
                return nil
            }
            return String(cString: output)
        }

        var ipv6 = in6_addr()
        if candidate.withCString({ inet_pton(AF_INET6, $0, &ipv6) }) == 1 {
            var output = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            guard inet_ntop(AF_INET6, &ipv6, &output, socklen_t(output.count)) != nil else {
                return nil
            }
            return String(cString: output).lowercased()
        }

        return nil
    }

    private static func isASCIILetterOrDigit(_ byte: UInt8) -> Bool {
        switch byte {
        case 97...122, 48...57:
            return true
        default:
            return false
        }
    }
}

nonisolated enum BrowserPageResolutionFailure: Equatable, Sendable {
    case unsupportedBrowser
    case invalidProcessIdentifier
    case invalidScreenPoint
    case accessibilityPermissionMissing
    case timedOut
    case elementUnavailable
    case pageUnavailable
    case accessibilityFailure
}

nonisolated enum BrowserPageResolution: Equatable, Sendable {
    case page(BrowserPageContext)
    case nonHTTPContent
    case unavailable(BrowserPageResolutionFailure)
}

nonisolated enum BrowserWebsitePolicy {
    static func blocksDragScrolling(
        resolution: BrowserPageResolution,
        ignoredHosts: [String]
    ) -> Bool {
        let rules = ignoredHosts.compactMap(WebsiteHost.normalized)
        guard !rules.isEmpty else { return false }

        switch resolution {
        case .page(let context):
            return rules.contains { ruleHost in
                WebsiteHost.matches(host: context.host, rule: ruleHost)
            }
        case .nonHTTPContent:
            return false
        case .unavailable:
            // Preserve the physical browser input instead of consuming it for
            // drag scrolling when an opted-in website rule cannot be checked.
            return true
        }
    }
}

nonisolated enum BrowserWindowBounds {
    private static let edgeTolerance: CGFloat = 32

    static func approximatelyMatches(_ resolved: CGRect, expected: CGRect) -> Bool {
        guard isValid(resolved), isValid(expected) else { return false }

        return abs(resolved.minX - expected.minX) <= edgeTolerance
            && abs(resolved.minY - expected.minY) <= edgeTolerance
            && abs(resolved.maxX - expected.maxX) <= edgeTolerance
            && abs(resolved.maxY - expected.maxY) <= edgeTolerance
    }

    private static func isValid(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite
            && rect.origin.y.isFinite
            && rect.width.isFinite
            && rect.height.isFinite
            && rect.width > 1
            && rect.height > 1
    }
}

@MainActor
protocol BrowserPageContextResolving: AnyObject {
    func resolvePage(
        at screenPoint: CGPoint,
        expectedWindowBounds: CGRect,
        processIdentifier: pid_t,
        bundleIdentifier: String?
    ) -> BrowserPageResolution

    func resolveFocusedPage(
        processIdentifier: pid_t,
        bundleIdentifier: String?
    ) -> BrowserPageResolution
}

@MainActor
final class AccessibilityBrowserPageContextResolver: BrowserPageContextResolving {
    private enum AttributeLookup {
        case value(CFTypeRef)
        case missing
        case failure(BrowserPageResolutionFailure)
    }

    private enum PageLookup {
        case reference(WebsiteHost.PageReference)
        case missing
        case failure(BrowserPageResolutionFailure)
    }

    private struct TraversalEntry {
        let element: AXUIElement
        let depth: Int
    }

    private static let webAreaRole = "AXWebArea"
    private static let windowRole = "AXWindow"

    private let messagingTimeout: Float
    private let maximumAncestorDepth: Int
    private let maximumTraversalDepth: Int
    private let maximumTraversalNodeCount: Int
    private let maximumResolutionDuration: TimeInterval
    private var activeResolutionDeadline: TimeInterval?

    init(
        messagingTimeout: Float = 0.03,
        maximumAncestorDepth: Int = 64,
        maximumTraversalDepth: Int = 12,
        maximumTraversalNodeCount: Int = 128,
        maximumResolutionDuration: TimeInterval = 0.15
    ) {
        let finiteTimeout = messagingTimeout.isFinite ? messagingTimeout : 0.03
        self.messagingTimeout = min(max(finiteTimeout, 0.005), 0.1)
        self.maximumAncestorDepth = min(max(maximumAncestorDepth, 1), 128)
        self.maximumTraversalDepth = min(max(maximumTraversalDepth, 1), 32)
        self.maximumTraversalNodeCount = min(max(maximumTraversalNodeCount, 8), 512)
        let finiteDuration = maximumResolutionDuration.isFinite ? maximumResolutionDuration : 0.15
        self.maximumResolutionDuration = min(max(finiteDuration, 0.05), 0.3)
    }

    func resolvePage(
        at screenPoint: CGPoint,
        expectedWindowBounds: CGRect,
        processIdentifier: pid_t,
        bundleIdentifier: String?
    ) -> BrowserPageResolution {
        let previousDeadline = activeResolutionDeadline
        activeResolutionDeadline = ProcessInfo.processInfo.systemUptime + maximumResolutionDuration
        defer { activeResolutionDeadline = previousDeadline }

        guard let browser = BrowserApplication.classify(bundleIdentifier: bundleIdentifier) else {
            return .unavailable(.unsupportedBrowser)
        }
        guard processIdentifier > 0 else {
            return .unavailable(.invalidProcessIdentifier)
        }
        guard screenPoint.x.isFinite,
              screenPoint.y.isFinite,
              abs(screenPoint.x) <= CGFloat(Float.greatestFiniteMagnitude),
              abs(screenPoint.y) <= CGFloat(Float.greatestFiniteMagnitude) else {
            return .unavailable(.invalidScreenPoint)
        }
        guard AXIsProcessTrusted() else {
            return .unavailable(.accessibilityPermissionMissing)
        }

        let application = AXUIElementCreateApplication(processIdentifier)
        if let failure = prepare(application: application, for: browser) {
            return .unavailable(failure)
        }

        var hitElement: AXUIElement?
        let hitTestError = AXUIElementCopyElementAtPosition(
            application,
            Float(screenPoint.x),
            Float(screenPoint.y),
            &hitElement
        )
        guard !resolutionDeadlineExceeded else {
            return .unavailable(.timedOut)
        }
        guard hitTestError == .success, let hitElement else {
            return .unavailable(failure(for: hitTestError, missing: .elementUnavailable))
        }

        if let failure = configureTimeout(for: hitElement) {
            return .unavailable(failure)
        }

        let window: AXUIElement
        switch containingWindow(for: hitElement) {
        case .value(let containingWindow):
            window = containingWindow
        case .failure(let failure):
            return .unavailable(failure)
        case .missing:
            return .unavailable(.elementUnavailable)
        }

        if let failure = validate(window: window, expectedBounds: expectedWindowBounds) {
            return .unavailable(failure)
        }

        switch pageFromOutermostWebAreaAncestor(
            of: hitElement,
            expectedWindow: window
        ) {
        case .reference(let reference):
            return resolution(from: reference)
        case .failure(let failure):
            return .unavailable(failure)
        case .missing:
            break
        }

        return resolvePage(in: window)
    }

    func resolveFocusedPage(
        processIdentifier: pid_t,
        bundleIdentifier: String?
    ) -> BrowserPageResolution {
        let previousDeadline = activeResolutionDeadline
        activeResolutionDeadline = ProcessInfo.processInfo.systemUptime + maximumResolutionDuration
        defer { activeResolutionDeadline = previousDeadline }

        guard let browser = BrowserApplication.classify(bundleIdentifier: bundleIdentifier) else {
            return .unavailable(.unsupportedBrowser)
        }
        guard processIdentifier > 0 else {
            return .unavailable(.invalidProcessIdentifier)
        }
        guard AXIsProcessTrusted() else {
            return .unavailable(.accessibilityPermissionMissing)
        }

        let application = AXUIElementCreateApplication(processIdentifier)
        if let failure = prepare(application: application, for: browser) {
            return .unavailable(failure)
        }

        switch elementAttribute(kAXFocusedUIElementAttribute, of: application) {
        case .value(let focusedElement):
            if let failure = configureTimeout(for: focusedElement) {
                return .unavailable(failure)
            }
            switch pageFromOutermostWebAreaAncestor(
                of: focusedElement,
                expectedWindow: nil
            ) {
            case .reference(let reference):
                return resolution(from: reference)
            case .failure(let failure):
                return .unavailable(failure)
            case .missing:
                break
            }
        case .failure(let failure):
            return .unavailable(failure)
        case .missing:
            break
        }

        switch elementAttribute(kAXFocusedWindowAttribute, of: application) {
        case .value(let window):
            return resolvePage(in: window)
        case .failure(let failure):
            return .unavailable(failure)
        case .missing:
            return .unavailable(.elementUnavailable)
        }
    }

    private func resolvePage(in window: AXUIElement) -> BrowserPageResolution {
        if let failure = configureTimeout(for: window) {
            return .unavailable(failure)
        }

        switch pageAttribute(kAXDocumentAttribute, of: window) {
        case .reference(let reference):
            return resolution(from: reference)
        case .failure(let failure):
            return .unavailable(failure)
        case .missing:
            break
        }

        switch pageFromBoundedWindowTraversal(window) {
        case .reference(let reference):
            return resolution(from: reference)
        case .failure(let failure):
            return .unavailable(failure)
        case .missing:
            return .unavailable(.pageUnavailable)
        }
    }

    private func prepare(
        application: AXUIElement,
        for browser: BrowserApplication
    ) -> BrowserPageResolutionFailure? {
        if let failure = configureTimeout(for: application) {
            return failure
        }

        guard browser == .googleChrome else { return nil }

        // Chromium lazily enables its native accessibility tree when assistive
        // technology first asks for the application's role.
        switch stringAttribute(kAXRoleAttribute, of: application) {
        case .failure(let failure):
            return failure
        case .value, .missing:
            return nil
        }
    }

    private func validate(
        window: AXUIElement,
        expectedBounds: CGRect
    ) -> BrowserPageResolutionFailure? {
        if let failure = configureTimeout(for: window) {
            return failure
        }

        switch rect(of: window) {
        case .value(let resolvedBounds):
            return BrowserWindowBounds.approximatelyMatches(
                resolvedBounds,
                expected: expectedBounds
            ) ? nil : .elementUnavailable
        case .failure(let failure):
            return failure
        case .missing:
            return .elementUnavailable
        }
    }

    private func pageFromOutermostWebAreaAncestor(
        of start: AXUIElement,
        expectedWindow: AXUIElement?
    ) -> PageLookup {
        var current: AXUIElement? = start
        var outermostWebArea: AXUIElement?
        var reachedWindow = false

        ancestorWalk: for _ in 0..<maximumAncestorDepth {
            guard let element = current else { break }

            switch stringAttribute(kAXRoleAttribute, of: element) {
            case .value(let role):
                if role == Self.webAreaRole {
                    outermostWebArea = element
                }
                if role == Self.windowRole {
                    if let expectedWindow, element != expectedWindow {
                        return .failure(.elementUnavailable)
                    }
                    reachedWindow = true
                    break ancestorWalk
                }
            case .failure(let failure):
                return .failure(failure)
            case .missing:
                break
            }

            switch elementAttribute(kAXParentAttribute, of: element) {
            case .value(let parent):
                if let failure = configureTimeout(for: parent) {
                    return .failure(failure)
                }
                current = parent
            case .failure(let failure):
                return .failure(failure)
            case .missing:
                current = nil
            }
        }

        // Do not trust a web area's URL unless the ancestor chain proves that it
        // belongs to this window. A detached frame can temporarily lack a parent.
        guard reachedWindow, let outermostWebArea else {
            return .missing
        }

        switch pageAttribute(kAXURLAttribute, of: outermostWebArea) {
        case .reference(.malformed):
            return .missing
        case .reference(let reference):
            return .reference(reference)
        case .failure(let failure):
            return .failure(failure)
        case .missing:
            return .missing
        }
    }

    private func pageFromBoundedWindowTraversal(_ window: AXUIElement) -> PageLookup {
        var queue = [TraversalEntry(element: window, depth: 0)]
        var nextIndex = 0
        var visited = Set<AXUIElement>()
        var pageReferences = Set<WebsiteHost.PageReference>()
        var foundWebAreaWithoutReference = false
        var traversalWasTruncated = false

        while nextIndex < queue.count, visited.count < maximumTraversalNodeCount {
            let entry = queue[nextIndex]
            nextIndex += 1

            guard visited.insert(entry.element).inserted else { continue }
            if let failure = configureTimeout(for: entry.element) {
                return .failure(failure)
            }

            var isWebArea = false
            switch stringAttribute(kAXRoleAttribute, of: entry.element) {
            case .value(let role) where role == Self.webAreaRole:
                isWebArea = true
                switch pageAttribute(kAXURLAttribute, of: entry.element) {
                case .reference(let reference):
                    pageReferences.insert(reference)
                case .failure(let failure):
                    return .failure(failure)
                case .missing:
                    foundWebAreaWithoutReference = true
                }
            case .failure(let failure):
                return .failure(failure)
            default:
                break
            }

            // Descendant web areas can represent cross-origin frames. Once a web area
            // is reached, never inspect nested web areas as candidates for the page URL.
            guard !isWebArea else { continue }

            switch childElements(of: entry.element) {
            case .value(let children):
                guard !children.isEmpty else { continue }
                guard entry.depth < maximumTraversalDepth else {
                    traversalWasTruncated = true
                    continue
                }

                let remainingCapacity = maximumTraversalNodeCount - queue.count
                guard remainingCapacity > 0 else {
                    traversalWasTruncated = true
                    continue
                }
                if children.count > remainingCapacity {
                    traversalWasTruncated = true
                }
                queue.append(contentsOf: children.prefix(remainingCapacity).map { child in
                    TraversalEntry(element: child, depth: entry.depth + 1)
                })
            case .failure(let failure):
                return .failure(failure)
            case .missing:
                break
            }
        }

        // When ancestry cannot prove which web area is the selected page, only
        // accept an unambiguous visible-window result. Side panels and developer
        // tools can expose additional top-level web areas.
        guard !traversalWasTruncated,
              nextIndex == queue.count,
              !foundWebAreaWithoutReference,
              pageReferences.count == 1,
              let reference = pageReferences.first else {
            return .missing
        }
        return .reference(reference)
    }

    private func containingWindow(for element: AXUIElement) -> ElementLookup {
        switch elementAttribute(kAXWindowAttribute, of: element) {
        case .value(let window):
            return .value(window)
        case .failure(let failure):
            return .failure(failure)
        case .missing:
            break
        }

        switch stringAttribute(kAXRoleAttribute, of: element) {
        case .value(let role) where role == Self.windowRole:
            return .value(element)
        case .failure(let failure):
            return .failure(failure)
        default:
            return .missing
        }
    }

    private enum ElementLookup {
        case value(AXUIElement)
        case missing
        case failure(BrowserPageResolutionFailure)
    }

    private enum StringLookup {
        case value(String)
        case missing
        case failure(BrowserPageResolutionFailure)
    }

    private enum ElementsLookup {
        case value([AXUIElement])
        case missing
        case failure(BrowserPageResolutionFailure)
    }

    private enum RectLookup {
        case value(CGRect)
        case missing
        case failure(BrowserPageResolutionFailure)
    }

    private func elementAttribute(_ attribute: String, of element: AXUIElement) -> ElementLookup {
        switch attributeValue(attribute, of: element) {
        case .value(let value):
            guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return .missing }
            return .value(value as! AXUIElement)
        case .missing:
            return .missing
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func stringAttribute(_ attribute: String, of element: AXUIElement) -> StringLookup {
        switch attributeValue(attribute, of: element) {
        case .value(let value):
            guard let string = value as? String else { return .missing }
            return .value(string)
        case .missing:
            return .missing
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func childElements(of element: AXUIElement) -> ElementsLookup {
        switch elementsAttribute(kAXVisibleChildrenAttribute, of: element) {
        case .value(let elements):
            return .value(elements)
        case .failure(let failure):
            return .failure(failure)
        case .missing:
            return elementsAttribute(kAXChildrenAttribute, of: element)
        }
    }

    private func elementsAttribute(_ attribute: String, of element: AXUIElement) -> ElementsLookup {
        switch attributeValue(attribute, of: element) {
        case .value(let value):
            guard let elements = value as? [AXUIElement] else { return .missing }
            return .value(elements)
        case .missing:
            return .missing
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func pageAttribute(_ attribute: String, of element: AXUIElement) -> PageLookup {
        switch attributeValue(attribute, of: element) {
        case .value(let value):
            if let url = value as? URL {
                return .reference(WebsiteHost.pageReference(from: url))
            }
            if let string = value as? String {
                return .reference(WebsiteHost.pageReference(from: string))
            }
            return .reference(.malformed)
        case .missing:
            return .missing
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func rect(of element: AXUIElement) -> RectLookup {
        let position: CGPoint
        switch pointAttribute(kAXPositionAttribute, of: element) {
        case .value(let value):
            position = value
        case .failure(let failure):
            return .failure(failure)
        case .missing:
            return .missing
        }

        let size: CGSize
        switch sizeAttribute(kAXSizeAttribute, of: element) {
        case .value(let value):
            size = value
        case .failure(let failure):
            return .failure(failure)
        case .missing:
            return .missing
        }

        return .value(CGRect(origin: position, size: size))
    }

    private enum PointLookup {
        case value(CGPoint)
        case missing
        case failure(BrowserPageResolutionFailure)
    }

    private enum SizeLookup {
        case value(CGSize)
        case missing
        case failure(BrowserPageResolutionFailure)
    }

    private func pointAttribute(_ attribute: String, of element: AXUIElement) -> PointLookup {
        switch attributeValue(attribute, of: element) {
        case .value(let value):
            guard CFGetTypeID(value) == AXValueGetTypeID() else { return .missing }
            let axValue = value as! AXValue
            guard AXValueGetType(axValue) == .cgPoint else { return .missing }
            var point = CGPoint.zero
            guard AXValueGetValue(axValue, .cgPoint, &point) else { return .missing }
            return .value(point)
        case .missing:
            return .missing
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func sizeAttribute(_ attribute: String, of element: AXUIElement) -> SizeLookup {
        switch attributeValue(attribute, of: element) {
        case .value(let value):
            guard CFGetTypeID(value) == AXValueGetTypeID() else { return .missing }
            let axValue = value as! AXValue
            guard AXValueGetType(axValue) == .cgSize else { return .missing }
            var size = CGSize.zero
            guard AXValueGetValue(axValue, .cgSize, &size) else { return .missing }
            return .value(size)
        case .missing:
            return .missing
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func attributeValue(_ attribute: String, of element: AXUIElement) -> AttributeLookup {
        guard !resolutionDeadlineExceeded else {
            return .failure(.timedOut)
        }

        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard !resolutionDeadlineExceeded else {
            return .failure(.timedOut)
        }

        switch error {
        case .success:
            guard let value else { return .missing }
            return .value(value)
        case .attributeUnsupported, .noValue:
            return .missing
        default:
            return .failure(failure(for: error, missing: .pageUnavailable))
        }
    }

    private func configureTimeout(for element: AXUIElement) -> BrowserPageResolutionFailure? {
        guard !resolutionDeadlineExceeded else { return .timedOut }
        let error = AXUIElementSetMessagingTimeout(element, messagingTimeout)
        guard !resolutionDeadlineExceeded else { return .timedOut }
        guard error != .success else { return nil }
        return failure(for: error, missing: .elementUnavailable)
    }

    private var resolutionDeadlineExceeded: Bool {
        guard let activeResolutionDeadline else { return false }
        return ProcessInfo.processInfo.systemUptime >= activeResolutionDeadline
    }

    private func resolution(from reference: WebsiteHost.PageReference) -> BrowserPageResolution {
        switch reference {
        case .httpHost(let host):
            guard let context = BrowserPageContext(host: host) else {
                return .unavailable(.pageUnavailable)
            }
            return .page(context)
        case .nonHTTPContent:
            return .nonHTTPContent
        case .malformed:
            return .unavailable(.pageUnavailable)
        }
    }

    private func failure(
        for error: AXError,
        missing fallback: BrowserPageResolutionFailure
    ) -> BrowserPageResolutionFailure {
        switch error {
        case .apiDisabled:
            return .accessibilityPermissionMissing
        case .cannotComplete:
            return .timedOut
        case .invalidUIElement:
            return .elementUnavailable
        case .noValue, .attributeUnsupported:
            return fallback
        default:
            return .accessibilityFailure
        }
    }
}
