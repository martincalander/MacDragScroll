//
//  IgnoredAppsPicker.swift
//  macdragscroll
//
//  Ignored-app discovery and picker controls.
//

import AppKit
import SwiftUI

private func localized(_ key: String, value: String, comment: String) -> String {
    AppLocalization.shared.localizedString(key, value: value, comment: comment)
}
struct CompactAppRow: View {
    let bundleId: String
    let onRemove: () -> Void

    @State private var appName = ""
    @State private var appIcon: NSImage?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            appIconView

            Text(appName.isEmpty ? bundleId : appName)
                .font(.system(size: 11))
                .lineLimit(1)

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 12))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundColor(isHovered ? .red : .secondary)
            .help(localized("remove", value: "Remove", comment: "Remove button"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.16) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onAppear(perform: loadAppInfo)
    }

    private var appIconView: some View {
        Group {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 16, height: 16)
    }

    private func loadAppInfo() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return
        }

        appIcon = NSWorkspace.shared.icon(forFile: url.path)
        appName = (url.lastPathComponent as NSString).deletingPathExtension
    }
}

struct InlineAppPickerView: View {
    let excludedApps: [String]
    let frontmostBundleId: String?
    let onAdd: (String) -> Void

    @State private var apps: [(name: String, bundleId: String, icon: NSImage?)] = []
    @State private var searchText = ""
    @State private var customBundleId = ""
    @State private var isLoading = true

    private var filteredApps: [(name: String, bundleId: String, icon: NSImage?)] {
        let available = apps.filter { !excludedApps.contains($0.bundleId) }

        guard !searchText.isEmpty else {
            return Array(available.prefix(7))
        }

        return Array(available.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleId.localizedCaseInsensitiveContains(searchText)
        }.prefix(7))
    }

    private var normalizedCustomBundleId: String {
        SettingsManager.normalizedBundleIdentifier(customBundleId)
    }

    private var canAddCustomBundleId: Bool {
        let bundleId = normalizedCustomBundleId
        return !bundleId.isEmpty && !excludedApps.contains(bundleId)
    }

    var body: some View {
        VStack(spacing: 7) {
            Label(localized("add_ignored_app", value: "Add Ignored App", comment: "Add ignored app title"), systemImage: "plus.app")
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            searchField
            customBundleField

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(height: 58)
            } else if filteredApps.isEmpty {
                Text(localized("no_apps_found", value: "No apps found", comment: "No apps found"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(height: 38)
            } else {
                VStack(spacing: 2) {
                    ForEach(filteredApps, id: \.bundleId) { app in
                        InlineAppPickerRow(
                            name: app.name,
                            bundleId: app.bundleId,
                            icon: app.icon,
                            isFrontmost: app.bundleId == frontmostBundleId,
                            onAdd: { onAdd(app.bundleId) }
                        )
                    }
                }
            }
        }
        .padding(.top, 4)
        .onAppear(perform: loadApps)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            TextField(localized("search", value: "Search", comment: "Search placeholder"), text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var customBundleField: some View {
        HStack(spacing: 6) {
            Image(systemName: "curlybraces")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            TextField(localized("custom_bundle_id", value: "Custom bundle ID", comment: "Custom bundle ID placeholder"), text: $customBundleId)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .onSubmit(addCustomBundleId)

            Button {
                addCustomBundleId()
            } label: {
                Label(localized("add", value: "Add", comment: "Add button"), systemImage: "plus.circle.fill")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(!canAddCustomBundleId)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.62), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .help(localized("tooltip_custom_bundle_id", value: "Use this when an app is not found in the picker. Example: com.company.AppName", comment: "Custom bundle ID tooltip"))
    }

    private func addCustomBundleId() {
        guard canAddCustomBundleId else { return }
        onAdd(normalizedCustomBundleId)
        customBundleId = ""
    }

    private func loadApps() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            let loadedApps = SettingsManager.shared.getInstalledApps(frontmostBundleId: frontmostBundleId)

            DispatchQueue.main.async {
                apps = loadedApps
                withAnimation(.easeOut(duration: 0.18)) {
                    isLoading = false
                }
            }
        }
    }
}


private struct InlineAppPickerRow: View {
    let name: String
    let bundleId: String
    let icon: NSImage?
    let isFrontmost: Bool
    let onAdd: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "app.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 16, height: 16)

            Text(name)
                .font(.system(size: 11))
                .lineLimit(1)

            if isFrontmost {
                Text(localized("current", value: "Current", comment: "Current app badge"))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.86), in: Capsule())
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundColor(isHovered ? .accentColor : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.16) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}
