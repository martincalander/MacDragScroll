//
//  BrowserWebsiteRuleTests.swift
//  macdragscrollTests
//
//  Browser website rule and persistence coverage.
//

import XCTest
@testable import macdragscroll

final class BrowserApplicationTests: XCTestCase {
    func testClassificationAcceptsOnlyExactSupportedBundleIdentifiers() {
        XCTAssertEqual(
            BrowserApplication.classify(bundleIdentifier: "com.apple.Safari"),
            .safari
        )
        XCTAssertEqual(
            BrowserApplication.classify(bundleIdentifier: "com.google.Chrome"),
            .googleChrome
        )
    }

    func testClassificationRejectsMissingVariantAndLookalikeBundleIdentifiers() {
        let unsupportedBundleIdentifiers: [String?] = [
            nil,
            "",
            "com.apple.safari",
            "com.apple.SafariTechnologyPreview",
            "com.google.Chrome.beta",
            "com.google.Chrome.canary",
            "com.google.Chrome.helper",
            "com.example.com.google.Chrome"
        ]

        for bundleIdentifier in unsupportedBundleIdentifiers {
            XCTAssertNil(
                BrowserApplication.classify(bundleIdentifier: bundleIdentifier),
                "\(bundleIdentifier ?? "nil") should not be classified as a supported browser"
            )
        }
    }
}

final class WebsiteHostTests: XCTestCase {
    func testNormalizationAcceptsHostAndHTTPURLForms() {
        XCTAssertEqual(WebsiteHost.normalized("example.com"), "example.com")
        XCTAssertEqual(
            WebsiteHost.normalized("  https://example.com/workspace/page?tab=1#section  "),
            "example.com"
        )
        XCTAssertEqual(WebsiteHost.normalized("http://sub.example.com"), "sub.example.com")
    }

    func testNormalizationCanonicalizesCaseAndTrailingRootDot() {
        XCTAssertEqual(WebsiteHost.normalized("ExAmPlE.CoM."), "example.com")
        XCTAssertEqual(
            WebsiteHost.normalized("HTTPS://Sub.Example.COM./path"),
            "sub.example.com"
        )
    }

    func testNormalizationDropsCredentialsPortPathQueryAndFragment() {
        XCTAssertEqual(
            WebsiteHost.normalized(
                "https://person:secret@Example.COM.:8443/private/path?token=hidden#fragment"
            ),
            "example.com"
        )
    }

    func testNormalizationCanonicalizesInternationalizedDomainNames() {
        XCTAssertEqual(WebsiteHost.normalized("bücher.example"), "xn--bcher-kva.example")
        XCTAssertEqual(
            WebsiteHost.normalized("https://BÜCHER.example/library"),
            "xn--bcher-kva.example"
        )
    }

    func testNormalizationCanonicalizesIPv4AndIPv6Addresses() {
        XCTAssertEqual(WebsiteHost.normalized("192.0.2.1"), "192.0.2.1")
        XCTAssertEqual(
            WebsiteHost.normalized("https://192.0.2.1:8443/path"),
            "192.0.2.1"
        )
        XCTAssertEqual(
            WebsiteHost.normalized("[2001:0db8:0:0:0:0:0:1]"),
            "2001:db8::1"
        )
        XCTAssertEqual(
            WebsiteHost.normalized("https://[2001:0db8:0:0:0:0:0:1]:8443/path"),
            "2001:db8::1"
        )
    }

    func testNormalizationRejectsEmptyMalformedAndInvalidHostnames() {
        let invalidValues = [
            "",
            "   \n",
            ".example.com",
            "example.com..",
            "example..com",
            "-example.com",
            "example-.com",
            "exam_ple.com",
            "example.com/path",
            "https://",
            "https://exa mple.com",
            "https://-example.com",
            "https://example-.com"
        ]

        for value in invalidValues {
            XCTAssertNil(WebsiteHost.normalized(value), "\(value) should be rejected")
        }
    }

    func testNormalizationRejectsOversizedRuleInputBeforeURLParsing() {
        let oversizedURL = "https://example.com/" + String(repeating: "a", count: 2_048)

        XCTAssertNil(WebsiteHost.normalized(oversizedURL))
    }

    func testNormalizationRejectsNonHTTPAndBrowserInternalReferences() {
        let nonWebsiteValues = [
            "about:blank",
            "chrome://settings",
            "file:///Users/example/index.html",
            "ftp://example.com/file",
            "mailto:person@example.com",
            "safari-extension://com.example.extension/page.html"
        ]

        for value in nonWebsiteValues {
            XCTAssertNil(WebsiteHost.normalized(value), "\(value) should not become a website rule")
        }
    }

    func testMatchingAcceptsExactHostAndLabelBoundedSubdomains() {
        XCTAssertTrue(WebsiteHost.matches(host: "notion.so", rule: "notion.so"))
        XCTAssertTrue(WebsiteHost.matches(host: "www.notion.so", rule: "notion.so"))
        XCTAssertTrue(WebsiteHost.matches(host: "TEAM.NOTION.SO.", rule: "Notion.SO."))
        XCTAssertTrue(
            WebsiteHost.matches(
                host: "sub.xn--bcher-kva.example",
                rule: "bücher.example"
            )
        )
    }

    func testMatchingRejectsSuffixConfusionAndParentDomains() {
        XCTAssertFalse(WebsiteHost.matches(host: "evilnotion.so", rule: "notion.so"))
        XCTAssertFalse(WebsiteHost.matches(host: "notion.so.evil.example", rule: "notion.so"))
        XCTAssertFalse(WebsiteHost.matches(host: "notion.so", rule: "www.notion.so"))
        XCTAssertFalse(WebsiteHost.matches(host: "other.example", rule: "notion.so"))
    }

    func testMatchingCanRequireAnExactHost() {
        XCTAssertTrue(
            WebsiteHost.matches(
                host: "notion.so",
                rule: "notion.so",
                includeSubdomains: false
            )
        )
        XCTAssertFalse(
            WebsiteHost.matches(
                host: "www.notion.so",
                rule: "notion.so",
                includeSubdomains: false
            )
        )
    }

    func testIPAddressRulesNeverUseSubdomainSuffixMatching() {
        XCTAssertTrue(WebsiteHost.matches(host: "192.0.2.1", rule: "192.0.2.1"))
        XCTAssertFalse(WebsiteHost.matches(host: "sub.192.0.2.1", rule: "192.0.2.1"))
        XCTAssertTrue(WebsiteHost.matches(host: "2001:db8::1", rule: "[2001:0db8::1]"))
    }
}

final class BrowserPageContextTests: XCTestCase {
    func testContextStoresOnlyACanonicalHost() throws {
        let context = try XCTUnwrap(BrowserPageContext(host: " ExAmPlE.CoM. "))

        XCTAssertEqual(context.host, "example.com")
    }

    func testContextCanonicalizesURLAndInternationalizedInput() throws {
        let urlContext = try XCTUnwrap(
            BrowserPageContext(host: "https://person:secret@Example.com:8443/private?token=hidden")
        )
        let internationalContext = try XCTUnwrap(
            BrowserPageContext(host: "bücher.example")
        )

        XCTAssertEqual(urlContext.host, "example.com")
        XCTAssertEqual(internationalContext.host, "xn--bcher-kva.example")
    }

    func testContextRejectsMissingMalformedAndInternalPageHosts() {
        XCTAssertNil(BrowserPageContext(host: ""))
        XCTAssertNil(BrowserPageContext(host: "bad host.example"))
        XCTAssertNil(BrowserPageContext(host: "about:blank"))
        XCTAssertNil(BrowserPageContext(host: "chrome://settings"))
    }
}

final class BrowserWebsitePolicyTests: XCTestCase {
    func testMatchingPageIsBlockedAndUnmatchedPageIsAllowed() throws {
        let ignoredPage = try XCTUnwrap(BrowserPageContext(host: "team.notion.so"))
        let allowedPage = try XCTUnwrap(BrowserPageContext(host: "example.com"))

        XCTAssertTrue(
            BrowserWebsitePolicy.blocksDragScrolling(
                resolution: .page(ignoredPage),
                ignoredHosts: ["notion.so"]
            )
        )
        XCTAssertFalse(
            BrowserWebsitePolicy.blocksDragScrolling(
                resolution: .page(allowedPage),
                ignoredHosts: ["notion.so"]
            )
        )
    }

    func testPageRulesNormalizeBeforeMatching() throws {
        let context = try XCTUnwrap(BrowserPageContext(host: "TEAM.NOTION.SO."))

        XCTAssertTrue(
            BrowserWebsitePolicy.blocksDragScrolling(
                resolution: .page(context),
                ignoredHosts: [" HTTPS://Notion.SO/workspace "]
            )
        )
    }

    func testNonHTTPContentRemainsAllowedWithWebsiteRules() {
        XCTAssertFalse(
            BrowserWebsitePolicy.blocksDragScrolling(
                resolution: .nonHTTPContent,
                ignoredHosts: ["notion.so"]
            )
        )
    }

    func testUnavailablePageFailsClosedWhenWebsiteRulesExist() {
        let failures: [BrowserPageResolutionFailure] = [
            .accessibilityPermissionMissing,
            .timedOut,
            .elementUnavailable,
            .pageUnavailable,
            .accessibilityFailure
        ]

        for failure in failures {
            XCTAssertTrue(
                BrowserWebsitePolicy.blocksDragScrolling(
                    resolution: .unavailable(failure),
                    ignoredHosts: ["notion.so"]
                ),
                "\(failure) should preserve physical browser input when a rule cannot be checked"
            )
        }
    }

    func testNoValidRulesNeverBlockAnyResolution() throws {
        let context = try XCTUnwrap(BrowserPageContext(host: "notion.so"))
        let emptyRuleSets = [
            [String](),
            ["", "about:blank", "bad host"]
        ]

        for ignoredHosts in emptyRuleSets {
            XCTAssertFalse(
                BrowserWebsitePolicy.blocksDragScrolling(
                    resolution: .page(context),
                    ignoredHosts: ignoredHosts
                )
            )
            XCTAssertFalse(
                BrowserWebsitePolicy.blocksDragScrolling(
                    resolution: .nonHTTPContent,
                    ignoredHosts: ignoredHosts
                )
            )
            XCTAssertFalse(
                BrowserWebsitePolicy.blocksDragScrolling(
                    resolution: .unavailable(.pageUnavailable),
                    ignoredHosts: ignoredHosts
                )
            )
        }
    }
}

final class BrowserWindowBoundsTests: XCTestCase {
    func testExactAndSmallFrameDifferencesMatch() {
        let expected = CGRect(x: 128, y: 31, width: 1_497, height: 909)

        XCTAssertTrue(BrowserWindowBounds.approximatelyMatches(expected, expected: expected))
        XCTAssertTrue(
            BrowserWindowBounds.approximatelyMatches(
                CGRect(x: 127, y: 31, width: 1_516, height: 913),
                expected: expected
            )
        )
    }

    func testStageManagerThumbnailDoesNotMatchHiddenFullWindow() {
        let thumbnail = CGRect(x: 16, y: 326, width: 147, height: 140)
        let hiddenWindow = CGRect(x: 127, y: 31, width: 1_516, height: 913)

        XCTAssertFalse(
            BrowserWindowBounds.approximatelyMatches(hiddenWindow, expected: thumbnail)
        )
    }

    func testDisplacedSameSizeWindowDoesNotMatch() {
        let expected = CGRect(x: 100, y: 100, width: 800, height: 600)
        let displaced = CGRect(x: 200, y: 100, width: 800, height: 600)

        XCTAssertFalse(
            BrowserWindowBounds.approximatelyMatches(displaced, expected: expected)
        )
    }

    func testInvalidFramesDoNotMatch() {
        let valid = CGRect(x: 100, y: 100, width: 800, height: 600)

        XCTAssertFalse(BrowserWindowBounds.approximatelyMatches(.null, expected: valid))
        XCTAssertFalse(
            BrowserWindowBounds.approximatelyMatches(
                CGRect(x: CGFloat.nan, y: 100, width: 800, height: 600),
                expected: valid
            )
        )
    }
}

final class WebsiteSettingsTests: XCTestCase {
    private var settings: SettingsManager!
    private var originalIgnoredWebsiteHosts: [String] = []
    private var originalAppListMode: AppListMode = .ignore
    private var originalExcludedApps: [String] = []
    private var originalAllowedApps: [String] = []

    override func setUp() {
        super.setUp()
        settings = SettingsManager.shared
        originalIgnoredWebsiteHosts = settings.ignoredWebsiteHosts
        originalAppListMode = settings.appListMode
        originalExcludedApps = settings.excludedApps
        originalAllowedApps = settings.allowedApps

        settings.ignoredWebsiteHosts = []
    }

    override func tearDown() {
        settings.ignoredWebsiteHosts = originalIgnoredWebsiteHosts
        settings.appListMode = originalAppListMode
        settings.excludedApps = originalExcludedApps
        settings.allowedApps = originalAllowedApps
        settings = nil
        super.tearDown()
    }

    func testWebsiteHostListNormalizationDeduplicatesAndRemovesRedundantSubdomains() {
        XCTAssertEqual(
            SettingsManager.normalizedWebsiteHosts([
                " HTTPS://Example.COM/path ",
                "example.com.",
                "sub.example.com",
                "bad host",
                "https://BÜCHER.example/page",
                "xn--bcher-kva.example"
            ]),
            ["example.com", "xn--bcher-kva.example"]
        )
        XCTAssertEqual(
            SettingsManager.normalizedWebsiteHosts([
                "deep.sub.example.com",
                "sub.example.com",
                "example.com"
            ]),
            ["example.com"]
        )
    }

    func testAssigningWebsiteHostsNormalizesDeduplicatesAndPersists() {
        PersistentPreferences.userDefaults.set(
            ["stale.example"],
            forKey: "ignoredWebsiteHosts"
        )
        settings.ignoredWebsiteHosts = [
            " HTTPS://Example.COM/path ",
            "example.com.",
            "sub.example.com",
            "bad host"
        ]

        let expectedHosts = ["example.com"]
        XCTAssertEqual(settings.ignoredWebsiteHosts, expectedHosts)
        XCTAssertEqual(
            PersistentPreferences.userDefaults.stringArray(forKey: "ignoredWebsiteHosts"),
            expectedHosts
        )
    }

    func testAddIgnoredWebsiteNormalizesAndRejectsDuplicatesAndInvalidInput() {
        settings.addIgnoredWebsite(" HTTPS://Notion.SO/workspace ")
        settings.addIgnoredWebsite("notion.so.")
        settings.addIgnoredWebsite("bad host")

        XCTAssertEqual(settings.ignoredWebsiteHosts, ["notion.so"])
        XCTAssertEqual(
            PersistentPreferences.userDefaults.stringArray(forKey: "ignoredWebsiteHosts"),
            ["notion.so"]
        )
    }

    func testRemoveIgnoredWebsiteAcceptsEquivalentURLInput() {
        settings.ignoredWebsiteHosts = ["notion.so", "example.com"]

        settings.removeIgnoredWebsite("https://NOTION.SO/workspace")

        XCTAssertEqual(settings.ignoredWebsiteHosts, ["example.com"])
    }

    func testToggleIgnoredWebsiteAddsThenRemovesCanonicalHost() {
        XCTAssertTrue(settings.toggleIgnoredWebsite("https://Notion.SO/workspace"))
        XCTAssertEqual(settings.ignoredWebsiteHosts, ["notion.so"])

        XCTAssertFalse(settings.toggleIgnoredWebsite("NOTION.SO."))
        XCTAssertTrue(settings.ignoredWebsiteHosts.isEmpty)
    }

    func testToggleIgnoredWebsiteRejectsInvalidInputWithoutChangingRules() {
        settings.ignoredWebsiteHosts = ["example.com"]

        XCTAssertFalse(settings.toggleIgnoredWebsite("chrome://settings"))
        XCTAssertEqual(settings.ignoredWebsiteHosts, ["example.com"])
    }

    func testWebsiteLookupMatchesSubdomainsButNotSuffixLookalikes() {
        settings.ignoredWebsiteHosts = ["notion.so"]

        XCTAssertTrue(settings.isWebsiteIgnored(host: "notion.so"))
        XCTAssertTrue(settings.isWebsiteIgnored(host: "team.notion.so"))
        XCTAssertFalse(settings.isWebsiteIgnored(host: "evilnotion.so"))
        XCTAssertFalse(settings.isWebsiteIgnored(host: "notion.so.evil.example"))
        XCTAssertFalse(settings.isWebsiteIgnored(host: nil))
        XCTAssertFalse(settings.isWebsiteIgnored(host: "bad host"))
    }

    func testWebsiteLookupReturnsTheRuleCoveringACurrentSubdomain() {
        settings.ignoredWebsiteHosts = ["notion.so", "other.example"]

        XCTAssertEqual(
            settings.matchingIgnoredWebsiteRule(for: "team.notion.so"),
            "notion.so"
        )
        XCTAssertNil(settings.matchingIgnoredWebsiteRule(for: "evilnotion.so"))
    }

    func testTogglingACurrentSubdomainRemovesItsCoveringParentRule() {
        settings.ignoredWebsiteHosts = ["notion.so", "other.example"]

        XCTAssertFalse(settings.toggleIgnoredWebsite("team.notion.so"))
        XCTAssertEqual(settings.ignoredWebsiteHosts, ["other.example"])
    }

    func testResetToDefaultsClearsAndPersistsWebsiteRules() {
        let snapshot = ResettableSettingsSnapshot(settings: settings)
        defer { snapshot.restore(to: settings) }

        settings.ignoredWebsiteHosts = ["notion.so", "example.com"]

        settings.resetToDefaults()

        XCTAssertTrue(settings.ignoredWebsiteHosts.isEmpty)
        XCTAssertEqual(
            PersistentPreferences.userDefaults.stringArray(forKey: "ignoredWebsiteHosts"),
            []
        )
    }

    func testWebsiteRulesRemainIndependentFromAppIgnoreAndAllowPolicies() {
        let chromeBundleIdentifier = BrowserApplication.googleChrome.rawValue
        settings.ignoredWebsiteHosts = ["notion.so"]

        settings.appListMode = .ignore
        settings.excludedApps = []
        XCTAssertFalse(settings.isAppExcluded(bundleIdentifier: chromeBundleIdentifier))
        XCTAssertTrue(settings.isWebsiteIgnored(host: "notion.so"))

        settings.excludedApps = [chromeBundleIdentifier]
        XCTAssertTrue(settings.isAppExcluded(bundleIdentifier: chromeBundleIdentifier))
        XCTAssertTrue(settings.isWebsiteIgnored(host: "notion.so"))

        settings.appListMode = .allow
        settings.allowedApps = [chromeBundleIdentifier]
        XCTAssertFalse(settings.isAppExcluded(bundleIdentifier: chromeBundleIdentifier))
        XCTAssertTrue(settings.isWebsiteIgnored(host: "notion.so"))

        settings.allowedApps = []
        XCTAssertTrue(settings.isAppExcluded(bundleIdentifier: chromeBundleIdentifier))
        XCTAssertTrue(settings.isWebsiteIgnored(host: "notion.so"))
    }
}

private struct ResettableSettingsSnapshot {
    let isEnabled: Bool
    let keepRunningInMenuBar: Bool
    let showIndicator: Bool
    let visualizerAnimationsEnabled: Bool
    let appListMode: AppListMode
    let excludedApps: [String]
    let allowedApps: [String]
    let ignoredWebsiteHosts: [String]
    let scrollSpeed: Double
    let deadZoneRadius: Double
    let acceleration: Double
    let overlayOpacity: Double
    let visualizerSize: Double
    let visualizerTintStyle: VisualizerTintStyle
    let liquidGlassIntensity: Double
    let reverseScrollDirection: Bool
    let verticalScrollingEnabled: Bool
    let horizontalScrollingEnabled: Bool
    let invertHorizontalScroll: Bool
    let keepCursorInPlace: Bool
    let precisionModeEnabled: Bool
    let precisionModifier: PrecisionModifier
    let precisionSpeedMultiplier: Double
    let appLanguage: AppLanguage
    let appAppearance: AppAppearance
    let triggerConfig: TriggerConfig

    init(settings: SettingsManager) {
        isEnabled = settings.isEnabled
        keepRunningInMenuBar = settings.keepRunningInMenuBar
        showIndicator = settings.showIndicator
        visualizerAnimationsEnabled = settings.visualizerAnimationsEnabled
        appListMode = settings.appListMode
        excludedApps = settings.excludedApps
        allowedApps = settings.allowedApps
        ignoredWebsiteHosts = settings.ignoredWebsiteHosts
        scrollSpeed = settings.scrollSpeed
        deadZoneRadius = settings.deadZoneRadius
        acceleration = settings.acceleration
        overlayOpacity = settings.overlayOpacity
        visualizerSize = settings.visualizerSize
        visualizerTintStyle = settings.visualizerTintStyle
        liquidGlassIntensity = settings.liquidGlassIntensity
        reverseScrollDirection = settings.reverseScrollDirection
        verticalScrollingEnabled = settings.verticalScrollingEnabled
        horizontalScrollingEnabled = settings.horizontalScrollingEnabled
        invertHorizontalScroll = settings.invertHorizontalScroll
        keepCursorInPlace = settings.keepCursorInPlace
        precisionModeEnabled = settings.precisionModeEnabled
        precisionModifier = settings.precisionModifier
        precisionSpeedMultiplier = settings.precisionSpeedMultiplier
        appLanguage = settings.appLanguage
        appAppearance = settings.appAppearance
        triggerConfig = settings.triggerConfig
    }

    func restore(to settings: SettingsManager) {
        settings.isEnabled = isEnabled
        settings.keepRunningInMenuBar = keepRunningInMenuBar
        settings.showIndicator = showIndicator
        settings.visualizerAnimationsEnabled = visualizerAnimationsEnabled
        settings.appListMode = appListMode
        settings.excludedApps = excludedApps
        settings.allowedApps = allowedApps
        settings.ignoredWebsiteHosts = ignoredWebsiteHosts
        settings.scrollSpeed = scrollSpeed
        settings.deadZoneRadius = deadZoneRadius
        settings.acceleration = acceleration
        settings.overlayOpacity = overlayOpacity
        settings.visualizerSize = visualizerSize
        settings.visualizerTintStyle = visualizerTintStyle
        settings.liquidGlassIntensity = liquidGlassIntensity
        settings.reverseScrollDirection = reverseScrollDirection
        settings.verticalScrollingEnabled = verticalScrollingEnabled
        settings.horizontalScrollingEnabled = horizontalScrollingEnabled
        settings.invertHorizontalScroll = invertHorizontalScroll
        settings.keepCursorInPlace = keepCursorInPlace
        settings.precisionModeEnabled = precisionModeEnabled
        settings.precisionModifier = precisionModifier
        settings.precisionSpeedMultiplier = precisionSpeedMultiplier
        settings.appLanguage = appLanguage
        settings.appAppearance = appAppearance
        settings.triggerConfig = triggerConfig
    }
}
