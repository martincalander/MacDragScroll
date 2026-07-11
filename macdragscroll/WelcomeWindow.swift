//
//  WelcomeWindow.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-07-08.
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
    @State private var logoBreathe = false
    @State private var isLeaving = false

    var body: some View {
        ZStack {
            LiquidGlassBackdrop(dimmingOpacity: 0.58)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                hero
                    .opacity(introVisible ? 1 : 0)
                    .offset(y: introVisible ? 0 : 24)
                    .scaleEffect(introVisible ? 1 : 0.94, anchor: .center)
                    .animation(.spring(response: 1.02, dampingFraction: 0.78).delay(0.10), value: introVisible)

                permissionCard
                    .opacity(introVisible ? 1 : 0)
                    .offset(y: introVisible ? 0 : 20)
                    .scaleEffect(introVisible ? 1 : 0.975, anchor: .center)
                    .animation(.spring(response: 0.90, dampingFraction: 0.84).delay(0.42), value: introVisible)

                githubStarAsk
                    .opacity(introVisible ? 1 : 0)
                    .offset(y: introVisible ? 0 : 18)
                    .scaleEffect(introVisible ? 1 : 0.98, anchor: .center)
                    .animation(.spring(response: 0.86, dampingFraction: 0.86).delay(0.62), value: introVisible)

                bottomActions
                    .opacity(introVisible ? 1 : 0)
                    .offset(y: introVisible ? 0 : 14)
                    .animation(.smooth(duration: 0.64).delay(0.88), value: introVisible)
            }
            .padding(28)
            .frame(maxWidth: 660)
            .opacity(isLeaving ? 0 : 1)
            .scaleEffect(isLeaving ? 0.972 : 1, anchor: .center)
            .offset(y: isLeaving ? -18 : 0)
            .blur(radius: isLeaving ? 1.8 : 0)
            .allowsHitTesting(!isLeaving)
            .animation(.smooth(duration: 0.34), value: isLeaving)
        }
        .frame(minWidth: 660, minHeight: 520)
        .onAppear {
            AppDelegate.refreshAccessibilityPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                introVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) {
                logoFloat = true
                logoBreathe = true
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
                    .shadow(color: .black.opacity(logoBreathe ? 0.19 : 0.12), radius: logoBreathe ? 18 : 12, x: 0, y: logoBreathe ? 8 : 5)
                    .scaleEffect(introVisible ? (logoBreathe ? 1.026 : 0.995) : 0.80)
                    .offset(y: introVisible ? (logoFloat ? -4 : 2) : 12)
                    .rotationEffect(.degrees(introVisible ? (logoFloat ? -1.1 : 1.2) : -5.0))
                    .animation(.spring(response: 0.92, dampingFraction: 0.62).delay(0.16), value: introVisible)
                    .animation(.easeInOut(duration: 2.7).repeatForever(autoreverses: true), value: logoFloat)
                    .animation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true), value: logoBreathe)

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
                Image(systemName: permissionState.hasRequiredPermissions ? "checkmark.shield.fill" : "hand.raised.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(permissionState.hasRequiredPermissions ? Color.primary : Color.orange)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(permissionState.hasRequiredPermissions
                         ? localized("permission_ready_title", value: "Accessibility Ready", comment: "Permissions ready title")
                         : localized("permission_setup_title", value: "Enable Accessibility", comment: "Permission setup title"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(permissionState.hasRequiredPermissions
                         ? localized("permission_ready_detail", value: "Mac Drag Scroll can listen for the mouse trigger and send scroll events.", comment: "Permissions ready detail")
                         : localized("permission_setup_detail", value: "Grant Accessibility to this app copy. Mac Drag Scroll starts automatically when access is enabled.", comment: "Permission setup detail"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if permissionState.hasRequiredPermissions {
                    WelcomeStatusPill(
                        title: localized("permission_granted", value: "Granted", comment: "Permission granted"),
                        systemImage: "checkmark",
                        tint: .primary
                    )
                } else {
                    Button {
                        AppDelegate.requestAccessibilityPermission()
                    } label: {
                        Label(localized("grant_permissions", value: "Grant Accessibility", comment: "Grant Accessibility button"), systemImage: "lock.open")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button {
                    AppDelegate.refreshAccessibilityPermission()
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
                    .scaledToFit()
                    .foregroundStyle(.primary)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)

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
                startOutro()
            } label: {
                Label(localized("welcome_get_started", value: "Get Started", comment: "Get started button"), systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(isLeaving)
        }
    }

    private func startOutro() {
        guard !isLeaving else { return }

        withAnimation(.smooth(duration: 0.34)) {
            isLeaving = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            onGetStarted()
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
            .adaptiveGlassEffect(tint: tint.opacity(0.10), in: Capsule())
    }
}
