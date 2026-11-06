import Foundation

@MainActor
final class DoubleCheckPipeline {
    private let doubleCheckService = DoubleCheckService()
    private let languageToolClient: LanguageToolClient
    private let maxRetries = AppConstants.maxDoubleCheckRetries

    init(languageToolClient: LanguageToolClient) {
        self.languageToolClient = languageToolClient
    }

    func validateCommentVariants(_ variants: [CommentVariant]) async -> [CommentVariant] {
        await withTaskGroup(of: CommentVariant?.self) { group in
            for variant in variants {
                group.addTask { [self] in
                    await self.validateAndCorrectComment(variant, retryCount: 0)
                }
            }

            var results: [CommentVariant] = []
            for await result in group {
                if let validated = result {
                    results.append(validated)
                }
            }
            return results
        }
    }

    func validateEmailDrafts(_ drafts: [EmailDraftVariant]) async -> [EmailDraftVariant] {
        await withTaskGroup(of: EmailDraftVariant?.self) { group in
            for draft in drafts {
                group.addTask { [self] in
                    await self.validateAndCorrectEmail(draft)
                }
            }

            var results: [EmailDraftVariant] = []
            for await result in group {
                if let validated = result {
                    results.append(validated)
                }
            }
            return results
        }
    }

    // MARK: - Private

    private func validateAndCorrectComment(_ variant: CommentVariant, retryCount: Int) async -> CommentVariant? {
        do {
            let result = try await doubleCheckService.check(text: variant.text, client: languageToolClient)

            if result.severity.shouldRegenerate && retryCount < maxRetries {
                // Return nil to signal regeneration needed
                return nil
            }

            // Return variant with auto-corrected spelling
            return CommentVariant(
                id: variant.id,
                label: variant.label,
                axes: variant.axes,
                text: result.correctedText
            )
        } catch {
            // If double-check fails, return the original variant
            return variant
        }
    }

    private func validateAndCorrectEmail(_ draft: EmailDraftVariant) async -> EmailDraftVariant? {
        do {
            let result = try await doubleCheckService.check(text: draft.body, client: languageToolClient)

            return EmailDraftVariant(
                id: draft.id,
                label: draft.label,
                axes: draft.axes,
                body: result.correctedText
            )
        } catch {
            return draft
        }
    }
}
