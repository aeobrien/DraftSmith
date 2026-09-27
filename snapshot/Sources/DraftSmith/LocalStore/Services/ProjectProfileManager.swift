import Foundation
import SwiftData

@Observable
@MainActor
final class ProjectProfileManager {
    private let modelContext: ModelContext
    private(set) var activeProfile: ProjectProfile?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadActiveProfile()
    }

    func createProfile(name: String) -> ProjectProfile {
        let profile = ProjectProfile(name: name)
        modelContext.insert(profile)
        try? modelContext.save()
        return profile
    }

    func deleteProfile(_ profile: ProjectProfile) {
        if profile.id == activeProfile?.id {
            activeProfile = nil
        }
        modelContext.delete(profile)
        try? modelContext.save()
    }

    func setActiveProfile(_ profile: ProjectProfile) {
        // Deactivate current default
        if let current = activeProfile {
            current.isDefault = false
        }
        profile.isDefault = true
        activeProfile = profile
        try? modelContext.save()
    }

    func fetchAllProfiles() -> [ProjectProfile] {
        let descriptor = FetchDescriptor<ProjectProfile>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func ensureDefaultProfile() {
        let profiles = fetchAllProfiles()
        if profiles.isEmpty {
            let defaultProfile = ProjectProfile(name: "Default", isDefault: true)
            modelContext.insert(defaultProfile)
            try? modelContext.save()
            activeProfile = defaultProfile
        } else if activeProfile == nil {
            activeProfile = profiles.first(where: { $0.isDefault }) ?? profiles.first
        }
    }

    func languageToolRuleConfig() -> (enabled: [String], disabled: [String]) {
        guard let profile = activeProfile else {
            return ([], [])
        }
        return (profile.enabledRules, profile.disabledRules)
    }

    func languageToolCheckConfig() -> LanguageToolCheckConfig {
        guard let profile = activeProfile else {
            return LanguageToolCheckConfig(level: "picky")
        }
        return profile.languageToolConfig()
    }

    // MARK: - Private

    private func loadActiveProfile() {
        let profiles = fetchAllProfiles()
        activeProfile = profiles.first(where: { $0.isDefault }) ?? profiles.first
    }
}
