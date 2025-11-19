//
//  KairosAuth.swift
//  KairosAmiqo
//
//  CENTRALIZED DESIGN SYSTEM - Single Source of Truth for ALL Visual Theming
//
//  ALL visual elements (colors, typography, spacing, shadows, radius) are defined here.
//  This enables easy theme switching via in-app settings (future feature).
//
//  📋 DESIGN STRATEGY:
//  - Phase 1 (Current): Finalize Amiqo theme (mint/teal gradient) across all screens
//  - Phase 2 (NOW): Theme switcher in Settings → toggle between Amiqo & Midnight Blue
//  - All screens reference KairosAuth.* → changing values here updates entire app
//
//  🎨 AVAILABLE THEMES:
//  1. Amiqo (Mint + Teal + Purple) - Original brand theme
//  2. Midnight Blue (Navy + Sky Blue) - Premium dark theme with Liquid Glass
//
//  ⚠️ NEVER hardcode colors/fonts/spacing in views - always use KairosAuth.*

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Typeалias to avoid SwiftUI.Color vs Color ambiguity  
typealias SUIColor = SwiftUI.Color

/// Namespace for centralized design system
/// ALL visual theming controlled here for easy theme switching
enum KairosAuth {
    
    // MARK: - Theme Management
    
    /// Available themes
    enum Theme: String, CaseIterable, Identifiable {
        case amiqo = "Amiqo"
        case midnightBlue = "Midnight Blue"
        case iceBlue = "Ice Blue"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .amiqo: return "Amiqo (Mint & Teal)"
            case .midnightBlue: return "Midnight Blue"
            case .iceBlue: return "Ice Blue"
            }
        }
        
        var description: String {
            switch self {
            case .amiqo: return "Original brand theme with mint accents"
            case .midnightBlue: return "Premium dark theme with glassmorphism"
            case .iceBlue: return "Light theme with sky blue accents"
            }
        }
    }
    
    /// Current active theme (persisted in UserDefaults)
    static var activeTheme: Theme {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: "KairosActiveTheme"),
                  let theme = Theme(rawValue: rawValue) else {
                return .midnightBlue // Default to Midnight Blue
            }
            return theme
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "KairosActiveTheme")
            NotificationCenter.default.post(name: .themeDidChange, object: nil)
        }
    }

    /// Preview palette used by ThemePickerView to showcase each theme without hardcoding colors in UI code
    enum ThemePreviewPalette {
        static func swatches(for theme: Theme) -> [SwiftUI.Color] {
            switch theme {
            case .amiqo:
                return [
                    SwiftUI.Color(red: 0.18, green: 0.20, blue: 0.66),
                    SwiftUI.Color(red: 0.180, green: 0.600, blue: 0.749),
                    SwiftUI.Color(red: 0.40, green: 0.92, blue: 0.88),
                    SwiftUI.Color(red: 0.10, green: 0.87, blue: 0.83)
                ]
            case .midnightBlue:
                return [
                    SwiftUI.Color(red: 0.039, green: 0.059, blue: 0.122),
                    SwiftUI.Color(red: 0.110, green: 0.227, blue: 0.369),
                    SwiftUI.Color(red: 0.180, green: 0.361, blue: 0.541),
                    SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886)
                ]
            case .iceBlue:
                return [
                    SwiftUI.Color(red: 0.910, green: 0.941, blue: 1.0),
                    SwiftUI.Color(red: 0.722, green: 0.831, blue: 0.941),
                    SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886),
                    SwiftUI.Color.white
                ]
            }
        }

        static func accent(for theme: Theme) -> SwiftUI.Color {
            switch theme {
            case .amiqo:
                return SwiftUI.Color(red: 0.40, green: 0.92, blue: 0.88)
            case .midnightBlue, .iceBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886)
            }
        }

        static func cardBackground(for theme: Theme) -> SwiftUI.Color {
            switch theme {
            case .amiqo:
                return SwiftUI.Color.white.opacity(0.06)
            case .midnightBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886).opacity(0.08)
            case .iceBlue:
                return SwiftUI.Color.white.opacity(0.40)
            }
        }

        static func cardBorder(for theme: Theme) -> SwiftUI.Color {
            switch theme {
            case .amiqo:
                return SwiftUI.Color.white.opacity(0.12)
            case .midnightBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886).opacity(0.20)
            case .iceBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886).opacity(0.30)
            }
        }

        static func text(for theme: Theme) -> SwiftUI.Color {
            switch theme {
            case .amiqo:
                return SwiftUI.Color.white.opacity(0.85)
            case .midnightBlue:
                return SwiftUI.Color(red: 0.910, green: 0.941, blue: 1.0)
            case .iceBlue:
                return SwiftUI.Color(red: 0.110, green: 0.227, blue: 0.369)
            }
        }

        static func buttonText(for theme: Theme) -> SwiftUI.Color {
            switch theme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.white
            case .iceBlue:
                return SwiftUI.Color(red: 0.039, green: 0.059, blue: 0.122)
            }
        }
    }

    // MARK: - Colors

    // MARK: - Colors

    enum Color {
        /// Gradient colors - Theme-dependent
        static var gradientStart: SwiftUI.Color {
            switch activeTheme {
            case .amiqo:
                return SwiftUI.Color(red: 0.18, green: 0.20, blue: 0.66) // Deep blue
            case .midnightBlue:
                return SwiftUI.Color(red: 0.039, green: 0.059, blue: 0.122) // #0A0F1F Deep navy
            case .iceBlue:
                return SwiftUI.Color(red: 0.910, green: 0.941, blue: 1.0) // #E8F0FF Ice blue light
            }
        }
        
        static var gradientEnd: SwiftUI.Color {
            switch activeTheme {
            case .amiqo:
                return SwiftUI.Color(red: 0.180, green: 0.600, blue: 0.749) // Blue-teal
            case .midnightBlue:
                return SwiftUI.Color(red: 0.102, green: 0.184, blue: 0.310) // #1A2F4F Royal blue
            case .iceBlue:
                return SwiftUI.Color(red: 0.722, green: 0.831, blue: 0.941) // #B8D4F0 Sky blue light
            }
        }

        /// Accent color - Theme-dependent
        static var accent: SwiftUI.Color {
            switch activeTheme {
            case .amiqo:
                return SwiftUI.Color(red: 0.40, green: 0.92, blue: 0.88) // Mint
            case .midnightBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886) // #4A90E2 Sky blue
            case .iceBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886) // #4A90E2 Sky blue (same as dark)
            }
        }

        /// Bright Teal accent - Theme-dependent
        static var teal: SwiftUI.Color {
            switch activeTheme {
            case .amiqo:
                return SwiftUI.Color(red: 0.10, green: 0.87, blue: 0.83) // #1ADED4
            case .midnightBlue:
                return SwiftUI.Color(red: 0.180, green: 0.361, blue: 0.541) // #2E5C8A Steel blue
            case .iceBlue:
                return SwiftUI.Color(red: 0.180, green: 0.361, blue: 0.541) // #2E5C8A Steel blue (same as dark)
            }
        }

        /// Purple accent - Theme-dependent
        static var purple: SwiftUI.Color {
            switch activeTheme {
            case .amiqo:
                return SwiftUI.Color(red: 0.65, green: 0.55, blue: 0.98) // #A78BFA
            case .midnightBlue:
                return SwiftUI.Color(red: 0.110, green: 0.227, blue: 0.369) // #1C3A5E Indigo
            case .iceBlue:
                return SwiftUI.Color(red: 0.110, green: 0.227, blue: 0.369) // #1C3A5E Indigo (same as dark)
            }
        }
        
        /// Brand text colors for onboarding/splash (use primaryText for consistency)
        static var brandTextColor: SwiftUI.Color {
            return primaryText  // Use same color as other text for consistency
        }
        
        static var brandTextShadow: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.black.opacity(0.70)  // Dark shadow for white text
            case .iceBlue:
                return SwiftUI.Color.black.opacity(0.25)  // DARK shadow for navy text on light background
            }
        }
        
        static var brandTextStroke: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.black  // Dark outline for white text
            case .iceBlue:
                return SwiftUI.Color.clear  // NO stroke on light backgrounds (unnecessary)
            }
        }
        
        /// Field input text color (use primaryText for consistency)
        static var fieldTextColor: SwiftUI.Color {
            return primaryText  // Use same color as other text for consistency
        }

        /// Deprecated colors
        @available(*, deprecated, message: "Use teal instead for better visibility")
        static let skyBlue = teal
        @available(*, deprecated, message: "Use teal instead for better contrast")
        static let softPurple = teal
        @available(*, deprecated, message: "Use teal instead for better color harmony")
        static let coral = teal

        /// Muted colors for completed/inactive items - Theme-aware
        static var mutedText: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.white.opacity(0.45)
            case .iceBlue:
                return SwiftUI.Color(red: 0.110, green: 0.227, blue: 0.369).opacity(0.45) // Navy @ 45%
            }
        }
        
        static var mutedBackground: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.white.opacity(0.04)
            case .iceBlue:
                return SwiftUI.Color(red: 0.110, green: 0.227, blue: 0.369).opacity(0.04) // Navy @ 4%
            }
        }

        /// Backgrounds - Theme-dependent with Liquid Glass effect
        static var cardBackground: SwiftUI.Color {
            switch activeTheme {
            case .amiqo:
                return SwiftUI.Color.white.opacity(0.06)
            case .midnightBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886).opacity(0.08) // #4A90E2 Blue tint 8%
            case .iceBlue:
                return SwiftUI.Color.white.opacity(0.40) // White glass 40%
            }
        }
        
        static var modalBackground: SwiftUI.Color {
            switch activeTheme {
            case .amiqo:
                return SwiftUI.Color.white.opacity(0.22)
            case .midnightBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886).opacity(0.12) // #4A90E2 Blue tint 12%
            case .iceBlue:
                return SwiftUI.Color.white.opacity(0.60) // White glass 60%
            }
        }
        
        static var modalSolidBackground: SwiftUI.Color {
            switch activeTheme {
            case .amiqo:
                return SwiftUI.Color(red: 0.12, green: 0.30, blue: 0.50).opacity(0.92)
            case .midnightBlue:
                return SwiftUI.Color(red: 0.110, green: 0.227, blue: 0.369).opacity(0.85) // #1C3A5E Indigo - Increased for readability
            case .iceBlue:
                return SwiftUI.Color.white.opacity(0.85) // White glass - Increased for readability
            }
        }
        
        static var fieldBackground: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.white.opacity(0.18)
            case .iceBlue:
                return SwiftUI.Color.white.opacity(0.50) // Stronger on light theme
            }
        }
        
        static var itemBackground: SwiftUI.Color {
            switch activeTheme {
            case .amiqo:
                return SwiftUI.Color.white.opacity(0.12)
            case .midnightBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886).opacity(0.10) // #4A90E2 Blue tint 10%
            case .iceBlue:
                return SwiftUI.Color.white.opacity(0.50) // White glass 50%
            }
        }
        
        static var selectedBackground: SwiftUI.Color {
            switch activeTheme {
            case .amiqo:
                return SwiftUI.Color(red: 0.10, green: 0.87, blue: 0.83).opacity(0.15)
            case .midnightBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886).opacity(0.20) // #4A90E2 Sky blue tint
            case .iceBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886).opacity(0.15) // #4A90E2 Sky blue tint
            }
        }

        /// Borders - Theme-dependent
        static var cardBorder: SwiftUI.Color {
            switch activeTheme {
            case .amiqo:
                return SwiftUI.Color.white.opacity(0.12)
            case .midnightBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886).opacity(0.20) // #4A90E2 Blue border
            case .iceBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886).opacity(0.30) // #4A90E2 Blue border (stronger on light)
            }
        }
        
        static var modalBorder: SwiftUI.Color {
            switch activeTheme {
            case .amiqo:
                return SwiftUI.Color.white.opacity(0.40)
            case .midnightBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886).opacity(0.30) // #4A90E2 Blue border
            case .iceBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886).opacity(0.40) // #4A90E2 Blue border (stronger on light)
            }
        }
        
        static var fieldBorder: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.white.opacity(0.25)
            case .iceBlue:
                return SwiftUI.Color(red: 0.290, green: 0.565, blue: 0.886).opacity(0.35) // Sky blue border
            }
        }

        /// Text colors - Theme-dependent
        static var primaryText: SwiftUI.Color {
            switch activeTheme {
            case .amiqo:
                return SwiftUI.Color.white.opacity(0.85)
            case .midnightBlue:
                return SwiftUI.Color(red: 0.910, green: 0.941, blue: 1.0) // #E8F0FF Ice blue (full opacity for max contrast)
            case .iceBlue:
                return SwiftUI.Color(red: 0.110, green: 0.227, blue: 0.369) // #1C3A5E Medium navy (correct color)
            }
        }
        
        static var secondaryText: SwiftUI.Color {
            switch activeTheme {
            case .amiqo:
                return SwiftUI.Color.white.opacity(0.80)
            case .midnightBlue:
                return SwiftUI.Color(red: 0.910, green: 0.941, blue: 1.0).opacity(0.85) // #E8F0FF Ice blue 85% (increased for better contrast)
            case .iceBlue:
                return SwiftUI.Color(red: 0.110, green: 0.227, blue: 0.369).opacity(0.85) // #1C3A5E Medium navy 85% (consistent hierarchy)
            }
        }
        
        static var tertiaryText: SwiftUI.Color {
            switch activeTheme {
            case .amiqo:
                return SwiftUI.Color.white.opacity(0.60)
            case .midnightBlue:
                return SwiftUI.Color(red: 0.910, green: 0.941, blue: 1.0).opacity(0.65) // #E8F0FF Ice blue 65% (increased for better readability)
            case .iceBlue:
                return SwiftUI.Color(red: 0.110, green: 0.227, blue: 0.369).opacity(0.65) // #1C3A5E Medium navy 65% (consistent hierarchy)
            }
        }

        /// Button text on accent background - Theme-aware
        static var buttonText: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.white // White on dark button backgrounds
            case .iceBlue:
                return SwiftUI.Color(red: 0.110, green: 0.227, blue: 0.369) // Navy on light buttons
            }
        }

        /// Semantic status colors (brand-aligned)
        static let statusConfirmed = teal              // Confirmed status - use brand teal (not system green)
        static let statusPending = teal                // Pending status - use brand teal with different icon
        
        /// Declined/error status - Theme-aware (tuned for each background)
        static var statusDeclined: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.red  // Standard red on dark backgrounds
            case .iceBlue:
                return SwiftUI.Color(red: 0.8, green: 0.0, blue: 0.0)  // Darker red for light background
            }
        }

        /// Semantic feedback colors - Theme-aware (tuned for readability)
        static var success: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.green  // Bright green on dark
            case .iceBlue:
                return SwiftUI.Color(red: 0.0, green: 0.6, blue: 0.0)  // Darker green for light theme
            }
        }
        
        static var error: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.red  // Bright red on dark
            case .iceBlue:
                return SwiftUI.Color(red: 0.8, green: 0.0, blue: 0.0)  // Darker red for light theme
            }
        }
        
        static var warning: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.orange  // Bright orange on dark
            case .iceBlue:
                return SwiftUI.Color(red: 0.9, green: 0.5, blue: 0.0)  // Darker orange for light theme
            }
        }

        /// Status backgrounds (for badges, alerts) - Theme-aware
        static var successBackground: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.green.opacity(0.12)  // Subtle on dark
            case .iceBlue:
                return SwiftUI.Color.green.opacity(0.20)  // More visible on light
            }
        }
        
        static var errorBackground: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.red.opacity(0.3)  // Moderate on dark
            case .iceBlue:
                return SwiftUI.Color.red.opacity(0.15)  // Softer on light
            }
        }
        
        static var warningBackground: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.orange.opacity(0.8)  // Strong on dark
            case .iceBlue:
                return SwiftUI.Color.orange.opacity(0.25)  // Softer on light
            }
        }

        /// Shadow colors - Theme-aware (darker on light themes)
        static var shadowLight: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.black.opacity(0.06)
            case .iceBlue:
                return SwiftUI.Color.black.opacity(0.10)
            }
        }
        
        static var shadowMedium: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.black.opacity(0.10)
            case .iceBlue:
                return SwiftUI.Color.black.opacity(0.15)
            }
        }
        
        static var shadowHeavy: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.black.opacity(0.30)
            case .iceBlue:
                return SwiftUI.Color.black.opacity(0.40)
            }
        }
        
        static var shadowModal: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.black.opacity(0.50)
            case .iceBlue:
                return SwiftUI.Color.black.opacity(0.60)
            }
        }

        /// Overlay colors - Theme-aware
        static var overlay: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.black.opacity(0.40)
            case .iceBlue:
                return SwiftUI.Color.black.opacity(0.50)
            }
        }
        
        static var scrim: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.black.opacity(0.30)
            case .iceBlue:
                return SwiftUI.Color.black.opacity(0.40)
            }
        }

        /// High-contrast text colors - Theme-aware (white on dark, navy on light)
        static var white: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.white
            case .iceBlue:
                return SwiftUI.Color(red: 0.110, green: 0.227, blue: 0.369) // Navy for light theme
            }
        }
        
        static var whiteSecondary: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.white.opacity(0.70)
            case .iceBlue:
                return SwiftUI.Color(red: 0.110, green: 0.227, blue: 0.369).opacity(0.70) // Navy @ 70%
            }
        }
        
        static var whiteTertiary: SwiftUI.Color {
            switch activeTheme {
            case .amiqo, .midnightBlue:
                return SwiftUI.Color.white.opacity(0.60)
            case .iceBlue:
                return SwiftUI.Color(red: 0.110, green: 0.227, blue: 0.369).opacity(0.60) // Navy @ 60%
            }
        }

        /// Background gradient
        static func backgroundGradient() -> LinearGradient {
            LinearGradient(
                gradient: Gradient(colors: [gradientStart, gradientEnd]),
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
    }

    // MARK: - Typography

    enum Typography {
        // Branding
        static let brandName = Font.system(size: 24, weight: .medium, design: .default)
        static let appName = Font.system(size: 44, weight: .bold, design: .rounded)
        static let brandSubtitle = Font.system(size: 22, weight: .medium, design: .default)

        // Screen titles
        static let screenTitle = Font.system(size: 22, weight: .medium, design: .default)

        // Buttons
        static let buttonLabel = Font.system(size: 17, weight: .regular, design: .rounded) // Changed to .regular (HIG standard)
        static let buttonLabelLarge = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let buttonIcon = Font.system(size: 17, weight: .regular) // Changed to .regular

        // Fields
        static let fieldLabel = Font.system(size: 15, weight: .regular)
        static let fieldInput = Font.system(size: 17, weight: .regular, design: .rounded)

        // Body
        static let body = Font.system(size: 16, weight: .medium)
        static let bodySmall = Font.system(size: 15, weight: .regular)

        // Special
        static let closeIcon = Font.system(size: 16, weight: .semibold)
        static let dividerText = Font.system(size: 14, weight: .medium)
        static let linkPrimary = Font.system(size: 18, weight: .bold)
        static let legalText = Font.system(size: 18, weight: .regular, design: .default)

        // Dashboard
        static let dashboardGreeting = Font.system(size: 28, weight: .bold, design: .rounded)
        static let dashboardSubtitle = Font.system(size: 16, weight: .regular, design: .default)
        static let cardTitle = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let cardSubtitle = Font.system(size: 15, weight: .medium, design: .default)
        static let itemTitle = Font.system(size: 17, weight: .regular, design: .rounded) // Changed to .regular (less heavy)
        static let itemSubtitle = Font.system(size: 14, weight: .regular, design: .default)
        static let timestamp = Font.system(size: 13, weight: .regular, design: .default)
        static let statusBadge = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let tutorialTitle = Font.system(size: 24, weight: .bold, design: .rounded)
        static let tutorialBody = Font.system(size: 16, weight: .regular, design: .default)

        // Tab Bar
        static let tabBarLabel = Font.system(size: 10, weight: .semibold)
    }
    enum Spacing {
        static let xs: CGFloat = 4              // Extra small (tight spacing)
        static let cardPadding: CGFloat = 20    // Reduced from 28 (modern iOS density)
        static let horizontalPadding: CGFloat = 20 // Reduced from 28 (more content visible)
        static let buttonVertical: CGFloat = 10 // Reduced from 16 (44pt touch target still met)
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 16          // Reduced from 20 (tighter section spacing)
        static let extraLarge: CGFloat = 20     // Reduced from 24 (modal top padding)
        static let brandingSpacing: CGFloat = 20

        // Dashboard
        static let dashboardHorizontal: CGFloat = 20
        static let dashboardVertical: CGFloat = 16
        static let cardSpacing: CGFloat = 16
        static let cardContentPadding: CGFloat = 16 // Reduced from 20 (compact cards)
        static let rowSpacing: CGFloat = 12
        static let itemSpacing: CGFloat = 12    // Reduced from 16 (list density)

        // Tab Bar
        static let tabBarHeight: CGFloat = 64
    }

    // MARK: - Corner Radius    // MARK: - Corner Radius

    enum Radius {
        static let card: CGFloat = 24          // Main cards (Dashboard, Login)
        static let modal: CGFloat = 24         // Modals
        static let button: CGFloat = 12        // Buttons, fields
        static let item: CGFloat = 16          // Event items, plan items
        static let small: CGFloat = 8          // Small icons, badges
        static let avatar: CGFloat = 8         // Avatar containers
    }

    // MARK: - Shadows

    enum Shadow {
        // Main card shadow - prominent "thick" elevated look (Z-index: 10)
        static let cardColor = SwiftUI.Color.black.opacity(0.20)
        static let cardRadius: CGFloat = 20
        static let cardY: CGFloat = 8

        // Secondary card shadow - subtle elevation for "floating" feel (Z-index: 20)
        static let itemColor = SwiftUI.Color.black.opacity(0.10)
        static let itemRadius: CGFloat = 8
        static let itemY: CGFloat = 3

        // Icon shadow
        static let iconColor = SwiftUI.Color.black.opacity(0.10)
        static let iconRadius: CGFloat = 12
        static let iconY: CGFloat = 4
    }

    // MARK: - Icon Sizes

    enum IconSize {
        static let appIcon: CGFloat = 130
        static let button: CGFloat = 17
        static let close: CGFloat = 16

        // Tab Bar
        static let tabBarIcon: CGFloat = 22

        // Dashboard
        static let heroIcon: CGFloat = 48
        static let cardIcon: CGFloat = 24
        static let itemIcon: CGFloat = 20
        static let badge: CGFloat = 16

        // Toolbar
        static let profileButton: CGFloat = 22

        // MARK: - Auth & Onboarding

        /// Splash screen app icon (launch screen)
        static let splashIcon: CGFloat = 240

        /// Login/onboarding branding icon
        static let brandingIcon: CGFloat = 180

        /// Social auth provider icons (Apple, Google, etc.)
        static let providerIcon: CGFloat = 50

        /// Success/error state icon circles
        static let successIcon: CGFloat = 100
        static let errorIcon: CGFloat = 100

        /// Tutorial slide feature icons
        static let tutorialIcon: CGFloat = 80
    }

    // MARK: - Animation

    enum Animation {
        /// Modal presentation animation - smooth, fluid spring
        /// Use for modal appearances and depth effects
        static let modalPresent = SwiftUI.Animation.spring(response: 0.55, dampingFraction: 0.75)

        /// Modal dismissal animation - snappy, responsive spring
        /// Use for closing modals and scrim dismissals
        static let modalDismiss = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)

        /// Page transition animation - smooth ease
        /// Use for navigation and step transitions
        static let pageTransition = SwiftUI.Animation.easeInOut(duration: 0.3)

        /// UI update animation - quick response
        /// Use for state changes and toggles
        static let uiUpdate = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.75)

        // MARK: - Auth Flow Animations

        /// Splash screen fade-in - gentle reveal
        /// Use for initial app launch branding
        static let splashFade = SwiftUI.Animation.easeOut(duration: 0.8)

        /// Connecting pulse animation - breathing glow
        /// Use for loading states and provider connection
        static let pulse = SwiftUI.Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)

        /// Success celebration bounce - joyful spring
        /// Use for successful authentication confirmation
        static let successBounce = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.6)

        /// Error shake - attention-grabbing spring
        /// Use for error states and failed authentication
        static let errorShake = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.7)
    }
}

// MARK: - Reusable Components

extension KairosAuth {

    /// Card Container
    struct Card<Content: View>: View {
        let content: () -> Content

        init(@ViewBuilder content: @escaping () -> Content) {
            self.content = content
        }

        var body: some View {
            VStack(spacing: KairosAuth.Spacing.large) {
                content()
            }
            .padding(KairosAuth.Spacing.cardPadding)
            .background(
                KairosAuth.Color.cardBackground
                    .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                    .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
            )
            .shadow(
                color: KairosAuth.Shadow.cardColor,
                radius: KairosAuth.Shadow.cardRadius,
                y: KairosAuth.Shadow.cardY
            )
            .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
        }
    }

    /// Branding Section
    struct BrandingSection: View {
        let subtitle: String

        var body: some View {
            VStack(spacing: KairosAuth.Spacing.brandingSpacing) {
                Image("AmiqoAppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: KairosAuth.IconSize.appIcon, height: KairosAuth.IconSize.appIcon)
                    .scaledToFit()
                    .shadow(
                        color: KairosAuth.Shadow.iconColor,
                        radius: KairosAuth.Shadow.iconRadius,
                        y: KairosAuth.Shadow.iconY
                    )
                
                // "Kairos" text with iOS native shadow style
                Text("Kairos")
                    .font(KairosAuth.Typography.brandName)
                    .foregroundColor(Color.brandTextColor)
                    .shadow(color: Color.brandTextShadow, radius: 8, x: 0, y: 2)  // Single shadow, iOS style
                
                // "Amiqo" text with iOS native shadow style
                Text("Amiqo")
                    .font(KairosAuth.Typography.appName)
                    .foregroundColor(Color.brandTextColor)
                    .padding(.top, -6)
                    .shadow(color: Color.brandTextShadow, radius: 8, x: 0, y: 2)  // Single shadow, iOS style
                
                Text(subtitle)
                    .font(KairosAuth.Typography.brandSubtitle)
                    .foregroundColor(KairosAuth.Color.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
    }

    /// Text Field
    struct TextField: View {
        let label: String
        @Binding var text: String
        var keyboardType: UIKeyboardType = .default
        var autocapitalization: TextInputAutocapitalization = .sentences

        var body: some View {
            VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                Text(label)
                    .font(KairosAuth.Typography.fieldLabel)
                    .foregroundColor(KairosAuth.Color.secondaryText)
                SwiftUI.TextField("", text: $text)
                    .padding()
                    .background(
                        KairosAuth.Color.fieldBackground
                            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                            .stroke(KairosAuth.Color.fieldBorder, lineWidth: 1)
                    )
                    .foregroundColor(KairosAuth.Color.fieldTextColor)
                    .font(KairosAuth.Typography.fieldInput)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .keyboardType(keyboardType)
            }
        }
    }

    /// Secure Field
    struct SecureField: View {
        let label: String
        @Binding var text: String

        var body: some View {
            VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                Text(label)
                    .font(KairosAuth.Typography.fieldLabel)
                    .foregroundColor(KairosAuth.Color.secondaryText)
                SwiftUI.SecureField("", text: $text)
                    .padding()
                    .background(
                        KairosAuth.Color.fieldBackground
                            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                            .stroke(KairosAuth.Color.fieldBorder, lineWidth: 1)
                    )
                    .foregroundColor(KairosAuth.Color.fieldTextColor)
                    .font(KairosAuth.Typography.fieldInput)
            }
        }
    }

    /// Primary Button (Solid Accent)
    struct PrimaryButton: View {
        let label: String
        let action: () -> Void
        var isLoading: Bool = false

        var body: some View {
            Button(action: action) {
                Text(isLoading ? "Loading..." : label)
                    .font(KairosAuth.Typography.buttonLabelLarge)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KairosAuth.Spacing.buttonVertical)
                    .background(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                            .fill(KairosAuth.Color.accent)
                    )
                    .foregroundColor(KairosAuth.Color.buttonText)
            }
            .disabled(isLoading)
        }
    }

    /// Secondary Button (Outlined/Filled)
    struct SecondaryButton: View {
        let icon: String?
        let label: String
        let action: () -> Void
        var outlined: Bool = false

        var body: some View {
            Button(action: action) {
                HStack(spacing: 10) {
                    if let icon {
                        Image(systemName: icon)
                            .font(KairosAuth.Typography.buttonIcon)
                            .foregroundColor(KairosAuth.Color.secondaryText)
                            .accessibilityHidden(true)
                    }
                    Text(label)
                        .font(KairosAuth.Typography.buttonLabel)
                        .foregroundColor(KairosAuth.Color.primaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, KairosAuth.Spacing.buttonVertical)
                .background(
                    Group {
                        if outlined {
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                .stroke(KairosAuth.Color.fieldBorder, lineWidth: 1)
                                .background(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                        .fill(KairosAuth.Color.cardBackground)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                .fill(KairosAuth.Color.fieldBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                        .stroke(KairosAuth.Color.fieldBorder, lineWidth: 1)
                                )
                        }
                    }
                )
            }
        }
    }

    /// Close Button
    struct CloseButton: View {
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(KairosAuth.Typography.closeIcon)
                    .foregroundColor(KairosAuth.Color.tertiaryText)
            }
            .accessibilityLabel("Close")
        }
    }
}

// MARK: - Preview

#if DEBUG
struct KairosAuthPreview: View {
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            KairosAuth.Color.backgroundGradient()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    KairosAuth.BrandingSection(subtitle: "Your AI buddy for effortless plans")

                    KairosAuth.Card {
                        KairosAuth.TextField(
                            label: "Email",
                            text: $email,
                            keyboardType: .emailAddress,
                            autocapitalization: .never
                        )

                        KairosAuth.SecureField(label: "Password", text: $password)

                        KairosAuth.PrimaryButton(label: "Sign In") {
                            print("Sign in tapped")
                        }

                        KairosAuth.SecondaryButton(
                            icon: "envelope.fill",
                            label: "Sign in with Email"
                        ) {
                            print("Email tapped")
                        }

                        KairosAuth.SecondaryButton(
                            icon: nil,
                            label: "Continue without account",
                            action: {
                                print("Continue tapped")
                            },
                            outlined: true
                        )
                    }
                }
                .padding(.vertical, 40)
            }
        }
    }
}

struct KairosAuthPreview_Previews: PreviewProvider {
    static var previews: some View {
        KairosAuthPreview()
    }
}
#endif

// MARK: - Card Hierarchy System (Level 1, 2, 3)

/**
 # Card Hierarchy Design System
 
 ## Level 1: Main Dashboard Cards (Container Cards)
 - Large cards that contain other elements
 - Examples: Active Plans, Upcoming Events, Recent Plans
 - Use: `DashboardCard { ... }`
 
 ## Level 2: Item Cards (Content Cards)
 - Cards within Level 1 cards
 - Examples: Individual plan items, event items
 - Standardized styling with teal accent
 
 ## Level 3: Badge/Chip Components
 - Small UI elements within Level 2
 - Examples: Status badges, participant counts, location badges
 
 ## Consistency Rules:
 
 ### Level 1 Cards:
 - Background: `KairosAuth.Color.cardBackground`
 - Border: `KairosAuth.Color.cardBorder` (1px)
 - Radius: `KairosAuth.Radius.card` (24pt)
 - Padding: 20pt
 
 ### Level 2 Item Cards:
 - Background: `KairosAuth.Color.fieldBackground`
 - Border: `KairosAuth.Color.fieldBorder` (1px)
 - Radius: `KairosAuth.Radius.button` (12pt)
 - Padding: `KairosAuth.Spacing.medium` (12pt)
 - Icon Color: `KairosAuth.Color.teal`
 - Icon Background: `KairosAuth.Color.teal.opacity(0.15)`
 
 ### Level 3 Badges:
 - Status Badge: teal text + 0.2 opacity background
 - Participant Count: teal color
 - Location Badge: teal color
 
 ### Interactive Elements:
 - All buttons/toggles: `KairosAuth.Color.accent`
 */

extension KairosAuth {

    // MARK: - Level 3: Badge Components

    /// Status Badge Component
    struct StatusBadge: View {
        let text: String

        var body: some View {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(KairosAuth.Color.teal)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    KairosAuth.Color.teal.opacity(0.2)
                        .clipShape(Capsule())
                )
        }
    }

    /// Participant Count Badge
    struct ParticipantBadge: View {
        let count: Int

        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12, weight: .medium))
                    .accessibilityHidden(true)
                Text("\(count)")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(KairosAuth.Color.teal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(count) participants")
        }
    }

    /// Location Badge
    struct LocationBadge: View {
        let location: String

        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12, weight: .medium))
                    .accessibilityHidden(true)
                Text(location)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(KairosAuth.Color.teal)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Level 2: Item Icon Container

    /// Standardized Icon Container for Item Cards
    struct ItemIconContainer: View {
        let icon: String
        let size: CGFloat

        init(icon: String, size: CGFloat = 32) {
            self.icon = icon
            self.size = size
        }

        var body: some View {
            Image(systemName: icon)
                .font(.system(size: KairosAuth.IconSize.itemIcon))
                .foregroundColor(KairosAuth.Color.teal)
                .frame(width: size, height: size)
                .background(
                    KairosAuth.Color.teal.opacity(0.15)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                )
                .accessibilityHidden(true)
        }
    }

    // MARK: - Card Header Template

    /// Standardized Card Header for Level 1 Cards
    struct CardHeader<RightContent: View>: View {
        let icon: String
        let title: String
        let subtitle: String
        let rightContent: RightContent?

        init(icon: String, title: String, subtitle: String, @ViewBuilder rightContent: () -> RightContent) {
            self.icon = icon
            self.title = title
            self.subtitle = subtitle
            self.rightContent = rightContent()
        }

        var body: some View {
            HStack(spacing: KairosAuth.Spacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: KairosAuth.IconSize.heroIcon))
                    .foregroundColor(KairosAuth.Color.accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(KairosAuth.Typography.cardTitle)
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(KairosAuth.Typography.cardSubtitle)
                        .foregroundColor(KairosAuth.Color.secondaryText)
                }

                Spacer()

                if let rightContent = rightContent {
                    rightContent
                }
            }
        }
    }

    // MARK: - Show More/Less Toggle

    /// Standardized Show More/Less Toggle
    struct ShowMoreToggle: View {
        let isExpanded: Bool
        let totalCount: Int
        let visibleCount: Int
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack {
                    Text(isExpanded ? "Show Less" : "Show \(totalCount - visibleCount) More")
                        .font(KairosAuth.Typography.itemSubtitle)
                        .foregroundColor(KairosAuth.Color.accent)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(KairosAuth.Color.accent)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, KairosAuth.Spacing.small)
            }
            .accessibilityLabel(isExpanded ? "Show fewer items" : "Show \(totalCount - visibleCount) more items")
        }
    }

    // MARK: - Motion & Parallax System

    /// Motion effects configuration and intensities
    enum Motion {
        /// User preference for parallax effects (stored in UserDefaults)
        static var isEnabled: Bool {
            get {
                // Default to true for first launch (wow factor)
                if !UserDefaults.standard.bool(forKey: "kairosMotionPreferenceSet") {
                    return true
                }
                return UserDefaults.standard.bool(forKey: "kairosParallaxEnabled")
            }
            set {
                UserDefaults.standard.set(true, forKey: "kairosMotionPreferenceSet")
                UserDefaults.standard.set(newValue, forKey: "kairosParallaxEnabled")
            }
        }

        /// Check if parallax should be active (respects system accessibility + user preference)
        static var shouldEnableParallax: Bool {
            #if os(iOS)
            // Respect system Reduce Motion setting (highest priority)
            if UIAccessibility.isReduceMotionEnabled {
                return false
            }

            // Respect Low Power Mode (battery saving)
            if ProcessInfo.processInfo.isLowPowerModeEnabled {
                return false
            }

            // Respect user preference
            return isEnabled
            #else
            return false // No parallax on non-iOS platforms
            #endif
        }

        /// Parallax intensities (max offset in points based on device tilt)
        static let modalIntensity: CGFloat = 15      // Modals - maximum floating effect
        static let cardIntensity: CGFloat = 12       // Dashboard cards - prominent
        static let listItemIntensity: CGFloat = 8    // List items - subtle
        static let tabBarIntensity: CGFloat = 6      // Tab bar - minimal (anchored)
        static let iconIntensity: CGFloat = 8        // Icons inside cards (nested)

        /// Scroll dampening factor (reduce parallax while scrolling)
        static let scrollDampeningFactor: CGFloat = 0.5  // 50% reduction
        static let scrollVelocityThreshold: CGFloat = 500 // pt/s - when to apply dampening
    }

    /// Parallax effect wrapper - applies device-tilt-based motion to content
    struct ParallaxStack<Content: View>: View {
        let intensity: CGFloat
        let content: () -> Content

        @StateObject private var motionService = MotionService.shared
        @State private var isScrolling = false

        init(intensity: CGFloat = Motion.cardIntensity, @ViewBuilder content: @escaping () -> Content) {
            self.intensity = intensity
            self.content = content
        }

        var body: some View {
            content()
                .offset(
                    x: Motion.shouldEnableParallax ? motionService.offsetX * effectiveIntensity : 0,
                    y: Motion.shouldEnableParallax ? motionService.offsetY * effectiveIntensity : 0
                )
                .onAppear {
                    motionService.startIfNeeded()
                }
        }

        /// Apply scroll dampening if scrolling fast
        private var effectiveIntensity: CGFloat {
            isScrolling ? intensity * Motion.scrollDampeningFactor : intensity
        }
    }
}

// MARK: - Motion Service (Singleton)

#if os(iOS)
import CoreMotion

/// Shared CoreMotion manager for all parallax effects
/// Singleton pattern prevents multiple motion listeners (battery optimization)
class MotionService: ObservableObject {
    static let shared = MotionService()

    @Published var offsetX: CGFloat = 0
    @Published var offsetY: CGFloat = 0

    private let motionManager = CMMotionManager()
    private var isActive = false

    private init() {}

    /// Start motion updates if not already active and parallax is enabled
    func startIfNeeded() {
        guard !isActive, KairosAuth.Motion.shouldEnableParallax else { return }
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0 // 30 FPS
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion = motion, let self = self else { return }

            // Convert device tilt to offset (normalized to -1...1 range)
            let x = CGFloat(motion.attitude.roll)
            let y = CGFloat(motion.attitude.pitch)

            // Update offsets (will be multiplied by intensity in ParallaxStack)
            self.offsetX = x
            self.offsetY = y
        }

        isActive = true
    }

    /// Stop motion updates (called when app backgrounds or parallax disabled)
    func stop() {
        guard isActive else { return }
        motionManager.stopDeviceMotionUpdates()
        isActive = false
        offsetX = 0
        offsetY = 0
    }

    deinit {
        stop()
    }
}
#else
// Fallback for non-iOS platforms (macOS previews, etc.)
class MotionService: ObservableObject {
    static let shared = MotionService()
    @Published var offsetX: CGFloat = 0
    @Published var offsetY: CGFloat = 0
    private init() {}
    func startIfNeeded() {}
    func stop() {}
}
#endif

// MARK: - Button Styles

/// Primary button style - Mint accent background with white text
struct KairosPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KairosAuth.Typography.buttonLabel)
            .foregroundColor(KairosAuth.Color.white)
            .padding(.horizontal, KairosAuth.Spacing.large)
            .padding(.vertical, KairosAuth.Spacing.buttonVertical)
            .background(KairosAuth.Color.accent)
            .cornerRadius(KairosAuth.Radius.button)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Secondary button style - Transparent with accent border
struct KairosSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KairosAuth.Typography.buttonLabel)
            .foregroundColor(KairosAuth.Color.accent)
            .padding(.horizontal, KairosAuth.Spacing.large)
            .padding(.vertical, KairosAuth.Spacing.buttonVertical)
            .background(KairosAuth.Color.accent.opacity(0.12))
            .cornerRadius(KairosAuth.Radius.button)
            .overlay(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                    .stroke(KairosAuth.Color.accent.opacity(0.3), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

/// Tertiary button style - Minimal style for low-emphasis actions
struct KairosTertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KairosAuth.Typography.buttonLabel)
            .foregroundColor(KairosAuth.Color.primaryText)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - Button Style Extensions

extension ButtonStyle where Self == KairosPrimaryButtonStyle {
    static var kairosPrimary: KairosPrimaryButtonStyle { KairosPrimaryButtonStyle() }
}

extension ButtonStyle where Self == KairosSecondaryButtonStyle {
    static var kairosSecondary: KairosSecondaryButtonStyle { KairosSecondaryButtonStyle() }
}

extension ButtonStyle where Self == KairosTertiaryButtonStyle {
    static var kairosTertiary: KairosTertiaryButtonStyle { KairosTertiaryButtonStyle() }
}

// MARK: - Notification Extension

extension Notification.Name {
    /// Posted when the active theme changes (Amiqo ↔ Midnight Blue)
    /// Views should listen to this to refresh colors reactively
    static let themeDidChange = Notification.Name("KairosThemeDidChange")
}
