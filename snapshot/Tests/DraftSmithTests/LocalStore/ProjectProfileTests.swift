import XCTest
@testable import DraftSmith

// NOTE: ProjectProfile triggers a SwiftData runtime crash when inserted into a ModelContext
// (SIGTRAP in computed property handling). Tests here only exercise non-persisted operations.

@MainActor
final class ProjectProfileTests: XCTestCase {

    // MARK: - Computed Accessors (no SwiftData insert needed)

    func testProfile_enabledAndDisabledRules() {
        let profile = ProjectProfile(name: "Test")
        profile.enabledRules = ["RULE_A", "RULE_B"]
        profile.disabledRules = ["RULE_C"]

        XCTAssertEqual(profile.enabledRules, ["RULE_A", "RULE_B"])
        XCTAssertEqual(profile.disabledRules, ["RULE_C"])
    }

    func testProfile_ruleConfigTuple() {
        let profile = ProjectProfile(name: "Config")
        profile.enabledRules = ["EN_A"]
        profile.disabledRules = ["DIS_B", "DIS_C"]

        let config = profile.languageToolConfig()
        XCTAssertEqual(config.enabledRules, ["EN_A"])
        XCTAssertEqual(config.disabledRules, ["DIS_B", "DIS_C"])
    }

    func testProfile_pickyMode_defaultsToTrue() {
        let profile = ProjectProfile(name: "Picky")
        XCTAssertTrue(profile.pickyMode)
        let config = profile.languageToolConfig()
        XCTAssertEqual(config.level, "picky")
    }

    func testProfile_pickyMode_canBeDisabled() {
        let profile = ProjectProfile(name: "NotPicky", pickyMode: false)
        XCTAssertFalse(profile.pickyMode)
        let config = profile.languageToolConfig()
        XCTAssertEqual(config.level, "default")
    }

    func testProfile_categories_roundTrip() {
        let profile = ProjectProfile(name: "Cats")
        profile.disabledCategories = ["CASING", "TYPOGRAPHY"]

        XCTAssertEqual(profile.disabledCategories, ["CASING", "TYPOGRAPHY"])
        let config = profile.languageToolConfig()
        XCTAssertEqual(config.disabledCategories, ["CASING", "TYPOGRAPHY"])
    }

    // MARK: - Custom Dictionary

    func testProfile_customDictionary_roundTrip() {
        let profile = ProjectProfile(name: "Dict")
        profile.customDictionary = ["Draftsmith", "Xcode", "MacBook"]

        XCTAssertEqual(profile.customDictionary, ["Draftsmith", "Xcode", "MacBook"])
    }

    func testProfile_customDictionary_emptyByDefault() {
        let profile = ProjectProfile(name: "Empty")
        XCTAssertTrue(profile.customDictionary.isEmpty)
    }

    // MARK: - Terminology

    func testProfile_terminology_roundTrip() {
        let entries = [
            TerminologyEntry(preferred: "analyse", rejected: "analyze"),
            TerminologyEntry(preferred: "colour", rejected: "color", note: "British English")
        ]
        let profile = ProjectProfile(name: "Terminology")
        profile.terminology = entries

        XCTAssertEqual(profile.terminology.count, 2)
        XCTAssertEqual(profile.terminology[0].preferred, "analyse")
        XCTAssertEqual(profile.terminology[0].rejected, "analyze")
        XCTAssertEqual(profile.terminology[1].note, "British English")
    }

    // MARK: - Severity Overrides

    func testProfile_severityOverrides_roundTrip() {
        let profile = ProjectProfile(name: "Severity")
        profile.severityOverrides = ["STYLE_RULE": "warning", "PASSIVE_VOICE": "info"]

        XCTAssertEqual(profile.severityOverrides["STYLE_RULE"], "warning")
        XCTAssertEqual(profile.severityOverrides["PASSIVE_VOICE"], "info")
    }

    // MARK: - Banned Phrases

    func testProfile_bannedPhrases_roundTrip() {
        let profile = ProjectProfile(name: "Bans")
        profile.bannedPhrases = ["going forward", "at this point in time"]

        XCTAssertEqual(profile.bannedPhrases.count, 2)
        XCTAssertTrue(profile.bannedPhrases.contains("going forward"))
    }

    // MARK: - Initialization

    func testProfile_defaults() {
        let profile = ProjectProfile()
        XCTAssertEqual(profile.name, "Default")
        XCTAssertFalse(profile.isDefault)
        XCTAssertTrue(profile.enabledRules.isEmpty)
        XCTAssertTrue(profile.disabledRules.isEmpty)
    }
}
