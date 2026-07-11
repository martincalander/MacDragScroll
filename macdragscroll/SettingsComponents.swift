//
//  SettingsComponents.swift
//  macdragscroll
//
//  Reusable controls for the Settings window.
//

import AppKit
import SwiftUI

private func localized(_ key: String, value: String, comment: String) -> String {
    AppLocalization.shared.localizedString(key, value: value, comment: comment)
}

#if DEBUG
struct DevelopmentWatermarkBadge: View {
    enum Style {
        case topBar
        case bottomBar
    }

    let style: Style

    private var title: String {
        switch style {
        case .topBar:
            return "DEV BUILD"
        case .bottomBar:
            return "Development Build"
        }
    }

    private var icon: String {
        switch style {
        case .topBar:
            return "hammer.fill"
        case .bottomBar:
            return "wrench.and.screwdriver.fill"
        }
    }

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: fontSize, weight: .semibold))
            .lineLimit(1)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .adaptiveGlassEffect(tint: tint, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(borderColor, lineWidth: 0.6)
            }
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 1)
            .help("Debug-only development build marker. Release builds do not show this.")
    }

    private var fontSize: CGFloat {
        switch style {
        case .topBar:
            return 10
        case .bottomBar:
            return 9
        }
    }

    private var horizontalPadding: CGFloat {
        switch style {
        case .topBar:
            return 9
        case .bottomBar:
            return 7
        }
    }

    private var verticalPadding: CGFloat {
        switch style {
        case .topBar:
            return 4
        case .bottomBar:
            return 2.5
        }
    }

    private var tint: Color {
        switch style {
        case .topBar:
            return Color.orange.opacity(0.20)
        case .bottomBar:
            return Color.orange.opacity(0.12)
        }
    }

    private var foregroundStyle: Color {
        switch style {
        case .topBar:
            return Color.orange
        case .bottomBar:
            return Color.orange.opacity(0.82)
        }
    }

    private var borderColor: Color {
        switch style {
        case .topBar:
            return Color.orange.opacity(0.34)
        case .bottomBar:
            return Color.orange.opacity(0.22)
        }
    }

    private var shadowColor: Color {
        switch style {
        case .topBar:
            return Color.orange.opacity(0.12)
        case .bottomBar:
            return Color.clear
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .topBar:
            return 5
        case .bottomBar:
            return 0
        }
    }
}
#endif

struct SettingsSidebarButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let isFocused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(tab.title, systemImage: tab.icon)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
                .background(
                    isSelected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.18) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay {
                    if isFocused && !isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.50), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityHint("Press Command-\(tab.keyboardShortcutLabel) to open \(tab.title).")
        .animation(.smooth(duration: 0.18), value: isSelected)
        .animation(.smooth(duration: 0.18), value: isFocused)
    }
}

enum SettingsKeyboardCommand {
    case select(SettingsTab)
    case previous
    case next

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let characters = event.charactersIgnoringModifiers?.lowercased()

        if flags.contains(.command), let characters, let tab = SettingsTab.tab(forShortcut: characters) {
            self = .select(tab)
            return
        }

        if flags.contains(.command) {
            switch event.keyCode {
            case 123, 126:
                self = .previous
                return
            case 124, 125:
                self = .next
                return
            default:
                break
            }

            if characters == "[" {
                self = .previous
                return
            }

            if characters == "]" {
                self = .next
                return
            }
        }

        if flags.contains(.control), event.keyCode == 48 {
            self = flags.contains(.shift) ? .previous : .next
            return
        }

        return nil
    }
}

struct SettingsKeyboardMonitor: NSViewRepresentable {
    let onCommand: (SettingsKeyboardCommand) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.view = view
        context.coordinator.install()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.view = nsView
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        var parent: SettingsKeyboardMonitor
        weak var view: NSView?
        private var monitor: Any?

        init(parent: SettingsKeyboardMonitor) {
            self.parent = parent
        }

        func install() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self,
                      let window = self.view?.window,
                      event.window === window,
                      let command = SettingsKeyboardCommand(event: event) else {
                    return event
                }

                self.parent.onCommand(command)
                return nil
            }
        }

        func uninstall() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            MainActor.assumeIsolated {
                uninstall()
            }
        }
    }
}


enum SettingsLayout {
    static let rowIconWidth: CGFloat = 18
    static let trailingControlWidth: CGFloat = 176
    static let compactControlHeight: CGFloat = 28
}

struct TintStyleRow: View {
    @Binding var selection: VisualizerTintStyle

    var body: some View {
        SettingRow(
            icon: "paintpalette",
            title: localized("visualizer_tint", value: "Tint", comment: "Visualizer tint setting"),
            tooltip: localized("tooltip_visualizer_tint", value: "Controls the subtle tint of the glass visualizer.", comment: "Visualizer tint tooltip")
        ) {
            SettingsOptionMenu(
                selection: $selection,
                options: VisualizerTintStyle.allCases,
                title: \.displayName
            )
        }
    }
}

struct GlassSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        LiquidGlassSurface(cornerRadius: 10, tintOpacity: 0.18, strokeOpacity: 0.38, shadowOpacity: 0.06) {
            VStack(spacing: 9) {
                content
            }
        }
    }
}

struct SettingRow<Trailing: View>: View {
    let icon: String
    let title: String
    let tooltip: String
    var trailingWidth: CGFloat? = SettingsLayout.trailingControlWidth
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: SettingsLayout.rowIconWidth)

            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            Group {
                if let trailingWidth {
                    trailing
                        .frame(width: trailingWidth, alignment: .trailing)
                } else {
                    trailing
                }
            }
        }
        .help(tooltip)
    }
}

struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    let tooltip: String

    var body: some View {
        SettingRow(icon: icon, title: title, tooltip: tooltip) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }
}

struct LanguagePickerRow: View {
    @Binding var selection: AppLanguage

    var body: some View {
        SettingRow(
            icon: "globe",
            title: localized("language", value: "Language", comment: "Language setting"),
            tooltip: localized("tooltip_language", value: "Choose the app language, or follow your system default.", comment: "Language tooltip")
        ) {
            SettingsOptionMenu(
                selection: $selection,
                options: AppLanguage.allCases,
                title: displayName(for:)
            )
        }
    }

    private func displayName(for language: AppLanguage) -> String {
        language == .system
            ? localized("system_default", value: "System Default", comment: "System default language")
            : language.displayName
    }
}

struct AppearancePickerRow: View {
    @Binding var selection: AppAppearance

    var body: some View {
        SettingRow(
            icon: "circle.lefthalf.filled",
            title: localized("appearance", value: "Appearance", comment: "Appearance setting"),
            tooltip: localized("tooltip_appearance", value: "Choose Light, Dark, or follow the system appearance.", comment: "Appearance tooltip")
        ) {
            SettingsOptionMenu(
                selection: $selection,
                options: AppAppearance.allCases,
                title: \.displayName
            )
        }
    }
}

private struct SettingsOptionMenu<Option: Identifiable & Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String
    var width: CGFloat = SettingsLayout.trailingControlWidth

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    if option == selection {
                        Label(title(option), systemImage: "checkmark")
                    } else {
                        Text(title(option))
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(title(selection))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(width: width, height: SettingsLayout.compactControlHeight, alignment: .leading)
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(0.70),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.34), lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: SettingsLayout.rowIconWidth)

            Text(title)
                .font(.system(size: 12))

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

struct LinkRow: View {
    let icon: String
    let title: String
    let url: URL
    var displayText: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: SettingsLayout.rowIconWidth)

            Text(title)
                .font(.system(size: 12))

            Spacer(minLength: 8)

            Link(destination: url) {
                Label(displayText ?? url.host ?? url.absoluteString, systemImage: "arrow.up.forward")
                    .font(.system(size: 11, weight: .medium))
            }
            .controlSize(.small)
        }
    }
}

struct AssetLinkRow: View {
    let assetName: String
    let title: String
    let url: URL

    var body: some View {
        HStack(spacing: 8) {
            Image(assetName)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: 15, height: 15)
                .frame(width: SettingsLayout.rowIconWidth)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 12))

            Spacer(minLength: 8)

            Link(destination: url) {
                Label(url.host ?? url.absoluteString, systemImage: "arrow.up.forward")
                    .font(.system(size: 11, weight: .medium))
            }
            .controlSize(.small)
        }
    }
}

struct StatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.22), lineWidth: 0.5)
            }
    }
}

struct SliderRow: View {
    let icon: String
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let formatString: String?
    let formatFunc: ((Double) -> String)?
    let tooltip: String

    init(
        icon: String,
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String,
        tooltip: String
    ) {
        self.icon = icon
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.formatString = format
        self.formatFunc = nil
        self.tooltip = tooltip
    }

    init(
        icon: String,
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: @escaping (Double) -> String,
        tooltip: String
    ) {
        self.icon = icon
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.formatString = nil
        self.formatFunc = format
        self.tooltip = tooltip
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: SettingsLayout.rowIconWidth)

            Text(title)
                .font(.system(size: 11))
                .frame(width: 88, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Slider(value: $value, in: range, step: step)
                .controlSize(.small)

            Text(formattedValue)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
        .help(tooltip)
    }

    private var formattedValue: String {
        if let formatFunc {
            return formatFunc(value)
        }

        if let formatString {
            return String(format: formatString, value)
        }

        return "\(value)"
    }
}

extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

struct TriggerCaptureButton: View {
    @Binding var triggerConfig: TriggerConfig
    @State private var isRecording = false
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            HStack(spacing: 5) {
                if isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)

                    Text(localized("recording", value: "Recording...", comment: "Recording..."))
                        .font(.system(size: 11))
                } else {
                    Text(triggerConfig.displayName)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minWidth: 86)
            .background(
                isRecording ? Color.red.opacity(0.14) : Color(nsColor: .controlBackgroundColor).opacity(0.65),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isRecording ? Color.red.opacity(0.42) : Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        isRecording = true
        SettingsManager.shared.isCapturingTrigger = true

        let eventMask: NSEvent.EventTypeMask = [
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown
        ]

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { event in
            handleMouseEvent(event)
            return nil
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { event in
            handleMouseEvent(event)
        }
    }

    private func stopRecording() {
        isRecording = false
        SettingsManager.shared.isCapturingTrigger = false

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    private func handleMouseEvent(_ event: NSEvent) {
        let button = Int(event.buttonNumber)
        let newConfig = TriggerConfig.captured(button: button, modifiers: event.modifierFlags)

        DispatchQueue.main.async {
            triggerConfig = newConfig
            stopRecording()
        }
    }
}
