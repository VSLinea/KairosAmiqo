//
//  BaseURL.swift
//  KairosAmiqo
//
//  Created by Lyra AI on 2025-10-05.
//

import Foundation

/// Centralized API endpoint configuration.
///
/// Set USE_MOCK=1 environment variable in Xcode scheme to use mock server (port 8056).
/// Default uses real Directus backend (port 8055).
enum BaseURL {
    #if DEBUG
        private static let useMock = ProcessInfo.processInfo.environment["USE_MOCK"] == "1"

        static let directus = URL(string: useMock
            ? "http://localhost:8056"  // Mock server (Phase 0 Day 1)
            : "http://localhost:8055"  // Real Directus
        )!
        static let nodeRed = URL(string: "http://localhost:1881")!
    #else
        // TODO: point to prod/staging
        static let directus = URL(string: "https://api.kairos.example.com")!
        static let nodeRed = URL(string: "https://flows.kairos.example.com")!
    #endif
}
