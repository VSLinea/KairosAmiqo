//
//  DirectusAPI.swift
//  KairosAmiqo
//
//  Created by GitHub Copilot on 2025-10-07.
//

import Foundation

/// Shared models for Directus API responses
struct DirectusError: Codable {
    let message: String
    let extensions: Extensions?

    struct Extensions: Codable {
        let code: String?
    }
}

struct DirectusErrorResponse: Codable {
    let errors: [DirectusError]
}
