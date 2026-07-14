import Foundation

struct OnboardingStep: Identifiable, Equatable {
    let id: String
    let eyebrowKey: String
    let titleKey: String
    let bodyKey: String
    let symbol: String
    let videoName: String

    static let all: [OnboardingStep] = [
        .init(
            id: "welcome",
            eyebrowKey: "onboarding.welcome.eyebrow",
            titleKey: "onboarding.welcome.title",
            bodyKey: "onboarding.welcome.body",
            symbol: "play.rectangle.fill",
            videoName: "onboarding-welcome"
        ),
        .init(
            id: "personal",
            eyebrowKey: "onboarding.personal.eyebrow",
            titleKey: "onboarding.personal.title",
            bodyKey: "onboarding.personal.body",
            symbol: "sparkles.tv.fill",
            videoName: "onboarding-personal"
        ),
        .init(
            id: "icloud",
            eyebrowKey: "onboarding.icloud.eyebrow",
            titleKey: "onboarding.icloud.title",
            bodyKey: "onboarding.icloud.body",
            symbol: "icloud.fill",
            videoName: "onboarding-icloud"
        ),
        .init(
            id: "trakt",
            eyebrowKey: "onboarding.trakt.eyebrow",
            titleKey: "onboarding.trakt.title",
            bodyKey: "onboarding.trakt.body",
            symbol: "arrow.triangle.2.circlepath",
            videoName: "onboarding-trakt"
        ),
        .init(
            id: "ready",
            eyebrowKey: "onboarding.ready.eyebrow",
            titleKey: "onboarding.ready.title",
            bodyKey: "onboarding.ready.body",
            symbol: "checkmark.seal.fill",
            videoName: "onboarding-ready"
        )
    ]
}
