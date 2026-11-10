import Foundation
import MLXLLM
import MLXLMCommon

struct SystemCapabilities: Sendable {
    let physicalMemory: UInt64
    let processorCount: Int

    static let current = SystemCapabilities(
        physicalMemory: ProcessInfo.processInfo.physicalMemory,
        processorCount: ProcessInfo.processInfo.processorCount
    )

    var isLowRAM: Bool {
        physicalMemory <= AppConstants.lowRAMThreshold
    }

    var memoryGB: Double {
        Double(physicalMemory) / (1024 * 1024 * 1024)
    }

    func recommendedModelConfig() -> ModelRecommendation {
        if physicalMemory >= 32 * 1024 * 1024 * 1024 {
            return .full
        } else if physicalMemory >= 16 * 1024 * 1024 * 1024 {
            return .standard
        } else {
            return .compact
        }
    }
}

enum ModelRecommendation: Sendable {
    case full       // 32GB+ — Qwen3 8B 4-bit
    case standard   // 16GB  — Qwen3 4B 4-bit
    case compact    // 8GB   — Qwen3 1.7B 4-bit

    var displayDescription: String {
        switch self {
        case .full:
            return "Full quality (Qwen3 8B, 4-bit quantisation)"
        case .standard:
            return "Standard quality (Qwen3 4B, 4-bit quantisation)"
        case .compact:
            return "Compact mode (Qwen3 1.7B for 8GB machines)"
        }
    }

    var modelSizeWarning: String? {
        switch self {
        case .full:
            return "This will download approximately 4.7 GB."
        case .standard:
            return "This will download approximately 2.5 GB."
        case .compact:
            return "This will download approximately 1.1 GB. Quality may be reduced on your 8 GB machine."
        }
    }

    var modelConfiguration: ModelConfiguration {
        switch self {
        case .full:
            return LLMRegistry.qwen3_8b_4bit
        case .standard:
            return LLMRegistry.qwen3_4b_4bit
        case .compact:
            return LLMRegistry.qwen3_1_7b_4bit
        }
    }
}
