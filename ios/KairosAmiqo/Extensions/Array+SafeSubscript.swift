//
//  Array+SafeSubscript.swift
//  KairosAmiqo
//
//  Created by Copilot on 2025-10-19.
//  Phase 3 - Task 12: Safe array subscripting for proposal card mapping
//

import Foundation

extension Array {
    /// Safe subscript that returns nil if index is out of bounds
    /// Usage: `array[safe: 5]` returns `nil` instead of crashing if array has < 6 elements
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
