//
//  IgnoredWebsitesPicker.swift
//  macdragscroll
//
//  Compact controls for managing browser website rules.
//

import AppKit
import Foundation
import SwiftUI

private func localized(_ key: String, value: String, comment: String) -> String {
    AppLocalization.shared.localizedString(key, value: value, comment: comment)
}

struct IgnoredWebsitesPicker: View {
    let ignoredWebsites: [String]
    let onAdd: (String) -> Void
    let onRemove: (String) -> Void

    @State private var websiteInput = ""

    private enum InputState {
        case empty
        case invalid
        case duplicate
        case ready(String)
    }

    private var inputState: InputState {
        guard !websiteInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .empty
        }

        guard let host = WebsiteHost.normalized(websiteInput) else {
            return .invalid
        }

        let existingHosts = ignoredWebsites.compactMap { WebsiteHost.normalized($0) }
        guard !existingHosts.contains(where: { existingRule in
            WebsiteHost.matches(host: host, rule: existingRule)
        }) else {
            return .duplicate
        }

        return .ready(host)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Label(
                    localized(
                        "ignored_websites_list",
                        value: "Ignored Websites",
                        comment: "Ignored websites list title"
                    ),
                    systemImage: "globe.badge.minus"
                )
                .font(.system(size: 12, weight: .semibold))

                Text(localized(
                    "ignored_websites_detail",
                    value: "Drag scrolling stays off in Safari and Google Chrome tabs that match these websites. Other websites keep working.",
                    comment: "Ignored websites detail"
                ))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if ignoredWebsites.isEmpty {
                Text(localized(
                    "no_ignored_websites",
                    value: "No ignored websites yet.",
                    comment: "No ignored websites message"
                ))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(ignoredWebsites.enumerated()), id: \.offset) { _, host in
                        CompactIgnoredWebsiteRow(host: host) {
                            onRemove(host)
                        }
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                Label(
                    localized(
                        "add_ignored_website",
                        value: "Add Ignored Website",
                        comment: "Add ignored website title"
                    ),
                    systemImage: "plus.circle"
                )
                .font(.system(size: 12, weight: .semibold))

                addField

                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
        }
    }

    private var addField: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(
                localized(
                    "website_domain_or_url",
                    value: "Domain or URL",
                    comment: "Website domain or URL placeholder"
                ),
                text: $websiteInput
            )
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .onSubmit(addWebsite)

            Button(action: addWebsite) {
                Label(
                    localized("add", value: "Add", comment: "Add button"),
                    systemImage: "plus.circle.fill"
                )
                .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(!canAddWebsite)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.62), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .help(localized(
            "tooltip_website_domain_or_url",
            value: "Enter a domain or web address, for example notion.so or https://www.notion.so.",
            comment: "Website domain or URL tooltip"
        ))
        .animation(.easeOut(duration: 0.12), value: validationMessage)
    }

    private var canAddWebsite: Bool {
        if case .ready = inputState {
            return true
        }
        return false
    }

    private var validationMessage: String? {
        switch inputState {
        case .empty, .ready:
            return nil
        case .invalid:
            return localized(
                "invalid_website",
                value: "Enter a valid domain or an HTTP(S) web address.",
                comment: "Invalid website message"
            )
        case .duplicate:
            return localized(
                "website_already_ignored",
                value: "That website is already ignored.",
                comment: "Website already ignored message"
            )
        }
    }

    private func addWebsite() {
        guard case let .ready(host) = inputState else { return }
        onAdd(host)
        websiteInput = ""
    }
}

private struct CompactIgnoredWebsiteRow: View {
    let host: String
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)

            Text(host)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(host)

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
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}
