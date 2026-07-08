//
//  WelcomeWindow.swift
//  macdragscroll
//
//  Created by OpenAI Codex on 2026-07-08.
//

import AppKit
import SwiftUI

private func localized(_ key: String, value: String, comment: String) -> String {
    AppLocalization.shared.localizedString(key, value: value, comment: comment)
}

struct WelcomeWindowView: View {
    let onGetStarted: () -> Void
    @ObservedObject private var permissionState = AppDelegate.permissionState
    @State private var introVisible = false
    @State private var logoFloat = false

    var body: some View {
        ZStack {
            LiquidGlassBackdrop(dimmingOpacity: 0.58)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                hero
                    .opacity(introVisible ? 1 : 0)
                    .offset(y: introVisible ? 0 : 18)
                    .scaleEffect(introVisible ? 1 : 0.965, anchor: .center)
                    .animation(.smooth(duration: 0.72).delay(0.08), value: introVisible)

                permissionCard
                    .opacity(introVisible ? 1 : 0)
                    .offset(y: introVisible ? 0 : 16)
                    .animation(.smooth(duration: 0.62).delay(0.30), value: introVisible)

                githubStarAsk
                    .opacity(introVisible ? 1 : 0)
                    .offset(y: introVisible ? 0 : 14)
                    .animation(.smooth(duration: 0.58).delay(0.46), value: introVisible)

                bottomActions
                    .opacity(introVisible ? 1 : 0)
                    .offset(y: introVisible ? 0 : 10)
                    .animation(.smooth(duration: 0.50).delay(0.62), value: introVisible)
            }
            .padding(28)
            .frame(maxWidth: 660)
        }
        .frame(minWidth: 660, minHeight: 520)
        .onAppear {
            permissionState.refresh()
            introVisible = true
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                logoFloat = true
            }
        }
    }

    private var hero: some View {
        LiquidGlassSurface(cornerRadius: 24, tintOpacity: 0.16, strokeOpacity: 0.42, shadowOpacity: 0.12, padding: EdgeInsets(top: 28, leading: 30, bottom: 28, trailing: 30)) {
            HStack(spacing: 22) {
                Image("BrandMark")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 7)
                    .scaleEffect(introVisible ? 1 : 0.86)
                    .offset(y: logoFloat ? -3 : 2)
                    .animation(.spring(response: 0.72, dampingFraction: 0.76).delay(0.12), value: introVisible)

                VStack(alignment: .leading, spacing: 8) {
                    Text(localized("welcome_title", value: "Welcome to Mac Drag Scroll", comment: "Welcome title"))
                        .font(.system(size: 31, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(localized("welcome_subtitle", value: "Windows-style drag scrolling, shaped for macOS.", comment: "Welcome subtitle"))
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(localized("welcome_author", value: "Made by Martin Calander", comment: "Welcome author"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var permissionCard: some View {
        LiquidGlassSurface(cornerRadius: 16, tintOpacity: 0.12, strokeOpacity: 0.32, shadowOpacity: 0.06) {
            HStack(spacing: 12) {
                Image(systemName: permissionState.hasAccessibilityPermission ? "checkmark.shield.fill" : "hand.raised.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(permissionState.hasAccessibilityPermission ? Color.primary : Color.orange)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(localized("welcome_permission_title", value: "Accessibility permission", comment: "Welcome permission title"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(permissionState.hasAccessibilityPermission
                         ? localized("welcome_permission_granted", value: "Ready to monitor your configured mouse trigger.", comment: "Welcome permission granted detail")
                         : localized("welcome_permission_needed", value: "Required so drag scrolling can listen for mouse input globally.", comment: "Welcome permission needed detail"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if permissionState.hasAccessibilityPermission {
                    WelcomeStatusPill(
                        title: localized("permission_granted", value: "Granted", comment: "Permission granted"),
                        systemImage: "checkmark",
                        tint: .primary
                    )
                } else {
                    Button {
                        AppDelegate.openAccessibilitySettings()
                    } label: {
                        Label(localized("open_system_settings", value: "Open System Settings", comment: "Open System Settings button"), systemImage: "gearshape")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button {
                    permissionState.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(localized("refresh", value: "Refresh", comment: "Refresh button"))
            }
        }
    }

    private var githubStarAsk: some View {
        LiquidGlassSurface(cornerRadius: 16, tintOpacity: 0.12, strokeOpacity: 0.32, shadowOpacity: 0.06) {
            HStack(spacing: 12) {
                Image("GitHubMark")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.primary)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(localized("welcome_star_title", value: "Star Mac Drag Scroll on GitHub", comment: "Welcome GitHub star title"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(localized("welcome_star_detail", value: "It helps the project and makes it easier to find later.", comment: "Welcome GitHub star detail"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    NSWorkspace.shared.open(UpdateManager.repositoryURL)
                } label: {
                    Label(localized("star_on_github", value: "Star", comment: "Star on GitHub button"), systemImage: "star")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 10) {
            Spacer()

            Button {
                onGetStarted()
            } label: {
                Label(localized("welcome_get_started", value: "Get Started", comment: "Get started button"), systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }
}

private struct WelcomeStatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .glassEffect(
                .regular.tint(tint.opacity(0.10)),
                in: Capsule()
            )
    }
}
