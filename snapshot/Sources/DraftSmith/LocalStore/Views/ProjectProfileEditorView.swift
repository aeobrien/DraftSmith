import SwiftUI

struct ProjectProfileEditorView: View {
    @Environment(ProjectProfileManager.self) private var profileManager
    @State private var profiles: [ProjectProfile] = []
    @State private var selectedProfile: ProjectProfile?
    @State private var newProfileName = ""
    @State private var showNewProfileSheet = false

    // Editable fields for selected profile
    @State private var customDictionaryText = ""
    @State private var bannedPhrasesText = ""
    @State private var newTermPreferred = ""
    @State private var newTermRejected = ""
    @State private var pickyMode = true
    @State private var disabledCategoriesText = ""
    @State private var commentExamples: [String: [String]] = [:]
    @State private var newExampleCategory = ""
    @State private var newExampleText = ""

    var body: some View {
        HSplitView {
            // Profile list
            VStack {
                List(profiles, id: \.id, selection: Binding(
                    get: { selectedProfile?.id },
                    set: { id in selectedProfile = profiles.first { $0.id == id } }
                )) { profile in
                    HStack {
                        Text(profile.name)
                        Spacer()
                        if profile.isDefault {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .listStyle(.sidebar)

                HStack {
                    Button(action: { showNewProfileSheet = true }) {
                        Image(systemName: "plus")
                    }
                    Spacer()
                    if let selected = selectedProfile, !selected.isDefault {
                        Button("Set as Active") {
                            profileManager.setActiveProfile(selected)
                            refreshProfiles()
                        }
                    }
                }
                .padding(8)
            }
            .frame(width: 200)

            // Profile editor
            if let profile = selectedProfile {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(profile.name)
                            .font(.title2)

                        // LanguageTool Checking Level
                        GroupBox("Checking Level") {
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Picky mode", isOn: $pickyMode)
                                    .onChange(of: pickyMode) { _, newValue in
                                        profile.pickyMode = newValue
                                    }
                                Text("Enables stricter checks for style, wordiness, passive voice, redundancy, and formality.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Category Control
                        GroupBox("Disabled Categories") {
                            VStack(alignment: .leading) {
                                Text("Comma-separated LanguageTool category IDs to disable (e.g. STYLE, REDUNDANCY, TYPOGRAPHY, CASING, PUNCTUATION).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("e.g. CASING,TYPOGRAPHY", text: $disabledCategoriesText)
                                    .textFieldStyle(.roundedBorder)
                                Button("Save Categories") {
                                    profile.disabledCategories = disabledCategoriesText
                                        .split(separator: ",")
                                        .map { String($0).trimmingCharacters(in: .whitespaces) }
                                        .filter { !$0.isEmpty }
                                }
                            }
                        }

                        // Custom Dictionary
                        GroupBox("Custom Dictionary") {
                            VStack(alignment: .leading) {
                                Text("One word per line. These words will not be flagged.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextEditor(text: $customDictionaryText)
                                    .font(.body.monospaced())
                                    .frame(minHeight: 100)
                                Button("Save Dictionary") {
                                    profile.customDictionary = customDictionaryText
                                        .split(separator: "\n")
                                        .map { String($0).trimmingCharacters(in: .whitespaces) }
                                        .filter { !$0.isEmpty }
                                }
                            }
                        }

                        // Terminology Preferences
                        GroupBox("Terminology Preferences") {
                            VStack(alignment: .leading) {
                                ForEach(profile.terminology) { entry in
                                    HStack {
                                        Text(entry.rejected)
                                            .strikethrough()
                                            .foregroundStyle(.red)
                                        Image(systemName: "arrow.right")
                                        Text(entry.preferred)
                                            .foregroundStyle(.green)
                                    }
                                }

                                HStack {
                                    TextField("Rejected", text: $newTermRejected)
                                    Image(systemName: "arrow.right")
                                    TextField("Preferred", text: $newTermPreferred)
                                    Button("Add") {
                                        guard !newTermPreferred.isEmpty, !newTermRejected.isEmpty else { return }
                                        var terms = profile.terminology
                                        terms.append(TerminologyEntry(
                                            preferred: newTermPreferred,
                                            rejected: newTermRejected
                                        ))
                                        profile.terminology = terms
                                        newTermPreferred = ""
                                        newTermRejected = ""
                                    }
                                }
                            }
                        }

                        // Banned Phrases
                        GroupBox("Banned Phrases") {
                            VStack(alignment: .leading) {
                                Text("One phrase per line.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextEditor(text: $bannedPhrasesText)
                                    .font(.body.monospaced())
                                    .frame(minHeight: 80)
                                Button("Save Banned Phrases") {
                                    profile.bannedPhrases = bannedPhrasesText
                                        .split(separator: "\n")
                                        .map { String($0).trimmingCharacters(in: .whitespaces) }
                                        .filter { !$0.isEmpty }
                                }
                            }
                        }

                        // Comment Examples per Category
                        GroupBox("Comment Examples") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Example sentences for natural comments, organised by issue category (e.g. Grammar, Typos, Style). These are provided to the AI when generating margin comments.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                ForEach(commentExamples.keys.sorted(), id: \.self) { category in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(category)
                                                .font(.subheadline.weight(.medium))
                                            Spacer()
                                            Button {
                                                commentExamples.removeValue(forKey: category)
                                                profile.commentExamples = commentExamples
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.caption)
                                            }
                                            .buttonStyle(.borderless)
                                        }

                                        ForEach(Array((commentExamples[category] ?? []).enumerated()), id: \.offset) { idx, example in
                                            HStack(spacing: 4) {
                                                Text(example)
                                                    .font(.caption)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                Button {
                                                    commentExamples[category]?.remove(at: idx)
                                                    if commentExamples[category]?.isEmpty == true {
                                                        commentExamples.removeValue(forKey: category)
                                                    }
                                                    profile.commentExamples = commentExamples
                                                } label: {
                                                    Image(systemName: "minus.circle")
                                                        .font(.caption2)
                                                }
                                                .buttonStyle(.borderless)
                                            }
                                        }
                                    }
                                    .padding(8)
                                    .background(Color(.controlBackgroundColor).opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }

                                Divider()

                                HStack {
                                    Picker("Category", selection: $newExampleCategory) {
                                        Text("Select\u{2026}").tag("")
                                        ForEach(Self.knownCategories, id: \.self) { cat in
                                            Text(cat).tag(cat)
                                        }
                                    }
                                    .frame(width: 160)

                                    TextField("Example comment sentence", text: $newExampleText)
                                    Button("Add") {
                                        let cat = newExampleCategory
                                        let text = newExampleText.trimmingCharacters(in: .whitespaces)
                                        guard !cat.isEmpty, !text.isEmpty else { return }
                                        var list = commentExamples[cat] ?? []
                                        list.append(text)
                                        commentExamples[cat] = list
                                        profile.commentExamples = commentExamples
                                        newExampleText = ""
                                    }
                                    .disabled(newExampleCategory.isEmpty || newExampleText.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .onAppear {
                    loadProfileData(profile)
                }
                .onChange(of: selectedProfile?.id) { _, _ in
                    if let profile = selectedProfile {
                        loadProfileData(profile)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select a Profile",
                    systemImage: "folder",
                    description: Text("Choose a profile from the list on the left, or create a new one.")
                )
            }
        }
        .sheet(isPresented: $showNewProfileSheet) {
            VStack(spacing: 16) {
                Text("New Project Profile")
                    .font(.headline)
                TextField("Profile Name", text: $newProfileName)
                HStack {
                    Button("Cancel") { showNewProfileSheet = false }
                    Button("Create") {
                        _ = profileManager.createProfile(name: newProfileName)
                        newProfileName = ""
                        showNewProfileSheet = false
                        refreshProfiles()
                    }
                    .disabled(newProfileName.isEmpty)
                }
            }
            .padding()
            .frame(width: 300)
        }
        .onAppear {
            profileManager.ensureDefaultProfile()
            refreshProfiles()
            // Auto-select the active profile or the first one
            if selectedProfile == nil {
                selectedProfile = profiles.first(where: { $0.isDefault }) ?? profiles.first
                if let selected = selectedProfile {
                    loadProfileData(selected)
                }
            }
        }
    }

    private func refreshProfiles() {
        profiles = profileManager.fetchAllProfiles()
    }

    private static let knownCategories = [
        "Grammar", "Typos", "Style", "Punctuation", "Casing",
        "Redundancy", "Typography", "Confused Words", "Compounding",
        "Collocations", "False Friends", "Gender Neutrality",
        "Semantics", "Plain English", "Creative Writing"
    ]

    private func loadProfileData(_ profile: ProjectProfile) {
        customDictionaryText = profile.customDictionary.joined(separator: "\n")
        bannedPhrasesText = profile.bannedPhrases.joined(separator: "\n")
        pickyMode = profile.pickyMode
        disabledCategoriesText = profile.disabledCategories.joined(separator: ", ")
        commentExamples = profile.commentExamples
    }
}
