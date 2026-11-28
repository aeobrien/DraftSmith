import Foundation

// Re-export EmailDraftResponse from LLMResponseModels as the canonical response type.
// The EmailDraftResponse struct in LLMResponseModels serves as the JSON contract (Section 11.3).
typealias EmailGenerationResponse = EmailDraftResponse
