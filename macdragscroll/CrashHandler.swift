//
//  CrashHandler.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-17.
//

import Foundation
import AppKit

// MARK: - Crash Handler

final class CrashHandler {
    static let shared = CrashHandler()
    
    // Cache version at init time so it's available during crash
    static var appVersion: String = "Unknown"
    
    private let crashLogPath: URL
    
    private init() {
        // Store crash logs in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("MacDragScroll")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        crashLogPath = appFolder.appendingPathComponent("crash.log")
    }
    
    // MARK: - Setup
    
    func setup() {
        setupSignalHandlers()
        setupExceptionHandler()
        checkForPreviousCrash()
    }
    
    // MARK: - Signal Handlers
    
    private func setupSignalHandlers() {
        // Handle common crash signals
        signal(SIGABRT) { signal in
            CrashHandler.shared.handleSignal(signal, name: "SIGABRT")
        }
        signal(SIGILL) { signal in
            CrashHandler.shared.handleSignal(signal, name: "SIGILL")
        }
        signal(SIGSEGV) { signal in
            CrashHandler.shared.handleSignal(signal, name: "SIGSEGV")
        }
        signal(SIGFPE) { signal in
            CrashHandler.shared.handleSignal(signal, name: "SIGFPE")
        }
        signal(SIGBUS) { signal in
            CrashHandler.shared.handleSignal(signal, name: "SIGBUS")
        }
        signal(SIGTRAP) { signal in
            CrashHandler.shared.handleSignal(signal, name: "SIGTRAP")
        }
    }
    
    private func handleSignal(_ signal: Int32, name: String) {
        let crashInfo = """
        Mac Drag Scroll Crash Report
        ============================
        Date: \(Date())
        Version: \(CrashHandler.appVersion)
        Signal: \(name) (\(signal))
        
        Stack Trace:
        \(Thread.callStackSymbols.joined(separator: "\n"))
        """
        
        // Write crash log synchronously (we're about to crash)
        try? crashInfo.write(to: crashLogPath, atomically: true, encoding: String.Encoding.utf8)
        
        // Re-raise the signal to get default behavior
        Darwin.signal(signal, SIG_DFL)
        Darwin.raise(signal)
    }
    
    // MARK: - Exception Handler
    
    private func setupExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            CrashHandler.shared.handleException(exception)
        }
    }
    
    private func handleException(_ exception: NSException) {
        let crashInfo = """
        Mac Drag Scroll Crash Report
        ============================
        Date: \(Date())
        Version: \(CrashHandler.appVersion)
        Exception: \(exception.name.rawValue)
        Reason: \(exception.reason ?? "Unknown")
        
        User Info:
        \(exception.userInfo?.description ?? "None")
        
        Stack Trace:
        \(exception.callStackSymbols.joined(separator: "\n"))
        """
        
        // Write crash log
        try? crashInfo.write(to: crashLogPath, atomically: true, encoding: String.Encoding.utf8)
    }
    
    // MARK: - Previous Crash Check
    
    private func checkForPreviousCrash() {
        guard FileManager.default.fileExists(atPath: crashLogPath.path) else { return }
        
        // Read crash log
        guard let crashLog = try? String(contentsOf: crashLogPath, encoding: .utf8) else {
            // Clean up unreadable file
            try? FileManager.default.removeItem(at: crashLogPath)
            return
        }
        
        // Delete the crash log file
        try? FileManager.default.removeItem(at: crashLogPath)
        
        // Show alert on main thread after a short delay to ensure app is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showCrashAlert(crashLog: crashLog)
        }
    }
    
    private func showCrashAlert(crashLog: String) {
        let alert = NSAlert()
        alert.messageText = Self.localized("crash_detected_title", value: "Mac Drag Scroll Crashed", comment: "Crash detected alert title")
        alert.informativeText = Self.localized("crash_detected_message", value: "The app crashed unexpectedly during the last session. You can copy the crash report to help diagnose the issue.", comment: "Crash detected alert message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: Self.localized("copy_report", value: "Copy Report", comment: "Copy crash report button"))
        alert.addButton(withTitle: Self.localized("dismiss", value: "Dismiss", comment: "Dismiss button"))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Copy crash report to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(crashLog, forType: .string)
        }
    }
    
    // MARK: - Safe Execution
    
    /// Execute a closure with error handling. If it fails, show an alert to the user.
    @discardableResult
    static func safeExecute<T>(_ operation: String, _ block: () throws -> T) -> T? {
        do {
            return try block()
        } catch {
            DispatchQueue.main.async {
                shared.showErrorAlert(operation: operation, error: error)
            }
            return nil
        }
    }
    
    /// Execute an async closure with error handling
    static func safeExecuteAsync(_ operation: String, _ block: @escaping () async throws -> Void) {
        Task {
            do {
                try await block()
            } catch {
                await MainActor.run {
                    shared.showErrorAlert(operation: operation, error: error)
                }
            }
        }
    }
    
    private func showErrorAlert(operation: String, error: Error) {
        let alert = NSAlert()
        alert.messageText = Self.localized("error_occurred_title", value: "An Error Occurred", comment: "Error occurred alert title")
        alert.informativeText = String(format: Self.localized("error_occurred_message", value: "An error occurred while %@:\n\n%@", comment: "Error occurred message"), operation, error.localizedDescription)
        alert.alertStyle = .warning
        alert.addButton(withTitle: Self.localized("ok", value: "OK", comment: "OK button"))
        alert.runModal()
    }
    
    // MARK: - Fatal Error Handler
    
    /// Show a fatal error alert and optionally quit the app
    static func fatalError(_ message: String, shouldQuit: Bool = false) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = localized("fatal_error_title", value: "Fatal Error", comment: "Fatal error alert title")
            alert.informativeText = message
            alert.alertStyle = .critical
            
            if shouldQuit {
                alert.addButton(withTitle: localized("quit", value: "Quit", comment: "Quit button"))
            } else {
                alert.addButton(withTitle: localized("ok", value: "OK", comment: "OK button"))
            }
            
            alert.runModal()
            
            if shouldQuit {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private static func localized(_ key: String, value: String, comment: String) -> String {
        AppLocalization.shared.localizedString(key, value: value, comment: comment)
    }
}
