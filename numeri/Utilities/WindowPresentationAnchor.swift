//
//  WindowPresentationAnchor.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

class WindowPresentationAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    private static var cachedWindow: ASPresentationAnchor?
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        // Return cached window if available to avoid repeated system service calls
        // This prevents triggering system services (RunningBoard, FrontBoard, usermanagerd)
        // that check process state when accessing UIApplication.shared properties
        if let cached = Self.cachedWindow {
            return cached
        }
        
        // Minimize system service triggers by:
        // 1. Using first(where:) instead of iterating through all scenes
        // 2. Avoiding isKeyWindow check which triggers additional system calls
        // 3. Caching the result to prevent repeated accesses
        
        // Find the first available UIWindowScene
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0 is UIWindowScene }) as? UIWindowScene else {
            // This should never happen in a properly initialized app
            // If no window scene exists, we cannot create a window in iOS 26+
            // Try one more time with a broader search
            if let anyWindowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first {
                let fallbackWindow = UIWindow(windowScene: anyWindowScene)
                Self.cachedWindow = fallbackWindow
                return fallbackWindow
            }
            // This indicates a serious app configuration issue
            // In practice, this should never occur
            fatalError("No UIWindowScene available. Cannot create window for authentication presentation.")
        }
        
        // Try to use existing window first
        if let window = windowScene.windows.first {
            Self.cachedWindow = window
            return window
        }
        
        // Fallback: create a minimal window with window scene
        // Note: This still requires accessing UIApplication.shared, but only once
        let fallbackWindow = UIWindow(windowScene: windowScene)
        Self.cachedWindow = fallbackWindow
        return fallbackWindow
        #elseif canImport(AppKit)
        if let cached = Self.cachedWindow {
            return cached
        }
        
        let window = NSApplication.shared.keyWindow 
            ?? NSApplication.shared.mainWindow 
            ?? NSApplication.shared.windows.first
            ?? NSWindow()
        Self.cachedWindow = window
        return window
        #endif
    }
    
    // Clear cache when window changes (optional, for memory management)
    static func clearCache() {
        cachedWindow = nil
    }
}

