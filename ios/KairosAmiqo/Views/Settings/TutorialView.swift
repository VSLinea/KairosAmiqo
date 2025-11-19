//
//  TutorialView.swift
//  KairosAmiqo
//
//  Tutorial modal with swipeable slides
//  Explains Plans, Events, and Features
//

import SwiftUI

/// Tutorial slide model
struct TutorialSlide: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
}

/// Tutorial modal view
struct TutorialView: View {
    let onDismiss: () -> Void

    @State private var currentPage = 0

    private let slides: [TutorialSlide] = [
        TutorialSlide(
            icon: "hand.wave.fill",
            title: "Welcome to Kairos",
            description: "Your AI buddy for effortless invitations. Coordinate schedules, send invites, and make gatherings happen—all in one place.",
            accentColor: KairosAuth.Color.accent
        ),
        TutorialSlide(
            icon: "paperplane.fill",
            title: "Active Invitations",
            description: "Invitations are live negotiations in progress. Propose times, invite friends, and coordinate together until everyone agrees.",
            accentColor: KairosAuth.Color.accent
        ),
        TutorialSlide(
            icon: "calendar.badge.checkmark",
            title: "Upcoming Events",
            description: "Events are confirmed and scheduled. Once an invitation is finalized, it becomes an event in your calendar—ready to happen!",
            accentColor: KairosAuth.Color.teal
        ),
        TutorialSlide(
            icon: "clock.arrow.circlepath",
            title: "Past Events",
            description: "See your recent social history. Missed an event? Tap 'Reschedule' for a second chance to connect!",
            accentColor: KairosAuth.Color.purple
        ),
        TutorialSlide(
            icon: "sparkles",
            title: "Smart Features",
            description: "Pull to refresh, expand cards for details. Active Invitations need action, Upcoming Events are ready, Past Events offer re-engagement!",
            accentColor: KairosAuth.Color.purple
        )
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Text(currentPage == slides.count - 1 ? "Done" : "Skip")
                            .font(KairosAuth.Typography.buttonLabel)
                            .foregroundColor(KairosAuth.Color.primaryText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                .padding(.top, KairosAuth.Spacing.dashboardVertical)

                // Slides
                TabView(selection: $currentPage) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                        TutorialSlideView(slide: slide)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // Navigation buttons
                HStack(spacing: KairosAuth.Spacing.medium) {
                    // Back button (hidden on first page)
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                currentPage -= 1
                            }
                        }) {
                            HStack(spacing: KairosAuth.Spacing.small) {
                                Image(systemName: "chevron.left")
                                    .accessibilityHidden(true)
                                    .font(KairosAuth.Typography.buttonIcon)
                                Text("Back")
                                    .font(KairosAuth.Typography.buttonLabel)
                            }
                            .foregroundColor(KairosAuth.Color.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, KairosAuth.Spacing.buttonVertical)
                            .background(
                                RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                                    .fill(KairosAuth.Color.fieldBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                                    .stroke(KairosAuth.Color.fieldBorder, lineWidth: 1)
                            )
                        }
                    }

                    // Next / Done button
                    Button(action: {
                        if currentPage < slides.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            onDismiss()
                        }
                    }) {
                        HStack(spacing: KairosAuth.Spacing.small) {
                            Text(currentPage == slides.count - 1 ? "Get Started" : "Next")
                                .font(KairosAuth.Typography.buttonLabelLarge)
                            if currentPage < slides.count - 1 {
                                Image(systemName: "chevron.right")
                                    .accessibilityHidden(true)
                                    .font(KairosAuth.Typography.buttonIcon)
                            }
                        }
                        .foregroundColor(KairosAuth.Color.buttonText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KairosAuth.Spacing.buttonVertical)
                        .background(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                                .fill(KairosAuth.Color.accent)
                        )
                    }
                }
                .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                .padding(.bottom, KairosAuth.Spacing.extraLarge)
            }
        }
        .background(KairosAuth.Color.backgroundGradient(), ignoresSafeAreaEdges: .all)
    }
}

/// Individual tutorial slide
private struct TutorialSlideView: View {
    let slide: TutorialSlide

    var body: some View {
        VStack(spacing: KairosAuth.Spacing.extraLarge) {
            Spacer()

            // Icon
            Image(systemName: slide.icon)
                .accessibilityHidden(true)
                .font(.system(size: KairosAuth.IconSize.tutorialIcon))
                .foregroundColor(slide.accentColor)
                .shadow(
                    color: slide.accentColor.opacity(0.3),
                    radius: 20,
                    y: 8
                )

            VStack(spacing: KairosAuth.Spacing.medium) {
                // Title
                Text(slide.title)
                    .font(KairosAuth.Typography.tutorialTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)
                    .multilineTextAlignment(.center)

                // Description
                Text(slide.description)
                    .font(KairosAuth.Typography.tutorialBody)
                    .foregroundColor(KairosAuth.Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Tutorial") {
    TutorialView(onDismiss: {
        print("Tutorial dismissed")
    })
}
