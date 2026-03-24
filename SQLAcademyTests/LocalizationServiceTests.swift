import XCTest
@testable import SQLAcademy

final class LocalizationServiceTests: XCTestCase {
    func testReturnsSelectedLanguageText() {
        let service = LocalizationService(
            userDefaults: UserDefaults(suiteName: "LocalizationServiceTests-\(UUID().uuidString)")!,
            preload: [
                .en: ["hello": "Hello"],
                .tr: ["hello": "Merhaba"]
            ]
        )
        service.language = .tr
        XCTAssertEqual(service.text("hello"), "Merhaba")
    }

    func testFallsBackToEnglish() {
        let service = LocalizationService(
            userDefaults: UserDefaults(suiteName: "LocalizationServiceTests-\(UUID().uuidString)")!,
            preload: [
                .en: ["hello": "Hello"],
                .tr: [:]
            ]
        )
        service.language = .tr
        XCTAssertEqual(service.text("hello"), "Hello")
    }

    func testQuizFlowKeysExistInBothLanguages() {
        let defaults = UserDefaults(suiteName: "LocalizationServiceTests-\(UUID().uuidString)")!
        let service = LocalizationService(userDefaults: defaults)
        let keys = [
            "module.questionProgress",
            "module.next",
            "module.previous",
            "module.finish",
            "module.reviewTitle",
            "module.correctCount",
            "module.passMessage",
            "module.failMessage",
            "tab.profile",
            "profile.heroTitle",
            "learn.packages",
            "learn.plus.title",
            "tutor.resume",
            "tutor.startOver",
            "tutor.askProfession",
            "module.m1.quiz5.prompt",
            "module.m8.quiz5.prompt"
        ]

        service.language = .tr
        for key in keys {
            XCTAssertNotEqual(service.text(key), key, "Missing Turkish localization for \(key)")
        }

        service.language = .en
        for key in keys {
            XCTAssertNotEqual(service.text(key), key, "Missing English localization for \(key)")
        }
    }
}
