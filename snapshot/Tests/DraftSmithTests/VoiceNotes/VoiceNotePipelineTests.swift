import XCTest
@testable import DraftSmith

final class VoiceNotePipelineTests: XCTestCase {

    // MARK: - State Transitions

    func testVoiceNotePipelineState_equatable() {
        XCTAssertEqual(VoiceNotePipelineState.idle, VoiceNotePipelineState.idle)
        XCTAssertEqual(VoiceNotePipelineState.recording, VoiceNotePipelineState.recording)
        XCTAssertEqual(VoiceNotePipelineState.transcribing, VoiceNotePipelineState.transcribing)
        XCTAssertEqual(VoiceNotePipelineState.editingTranscript, VoiceNotePipelineState.editingTranscript)
        XCTAssertEqual(VoiceNotePipelineState.generatingVariants, VoiceNotePipelineState.generatingVariants)
        XCTAssertEqual(VoiceNotePipelineState.complete, VoiceNotePipelineState.complete)
    }

    func testVoiceNotePipelineState_allStatesAreDifferent() {
        let states: [VoiceNotePipelineState] = [
            .idle, .recording, .transcribing, .editingTranscript, .generatingVariants, .complete
        ]

        for i in 0..<states.count {
            for j in (i + 1)..<states.count {
                XCTAssertNotEqual(states[i], states[j],
                                   "\(states[i]) should not equal \(states[j])")
            }
        }
    }

    // MARK: - Pipeline State: idle -> recording -> transcribing -> editing -> generating -> complete

    func testExpectedStateTransitionOrder() {
        // Document the expected state flow
        let expectedFlow: [VoiceNotePipelineState] = [
            .idle,
            .recording,
            .transcribing,
            .editingTranscript,
            .generatingVariants,
            .complete
        ]

        XCTAssertEqual(expectedFlow.count, 6, "Pipeline has 6 states in its lifecycle")

        // Verify each state is distinct
        let uniqueStates = Set(expectedFlow.map { "\($0)" })
        XCTAssertEqual(uniqueStates.count, 6, "All states should be unique")
    }

    // MARK: - AudioRecording Model

    func testAudioRecording_properties() {
        let uuid = UUID()
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        let recording = AudioRecording(url: url, duration: 5.0, annotationUUID: uuid)

        XCTAssertEqual(recording.url, url)
        XCTAssertEqual(recording.duration, 5.0)
        XCTAssertEqual(recording.annotationUUID, uuid)
    }

    // MARK: - TranscriptionResult Model

    func testTranscriptionResult_properties() {
        let segment = TranscriptionSegment(text: "Hello world", start: 0.0, end: 2.5)
        let result = TranscriptionResult(
            text: "Hello world",
            segments: [segment],
            language: "en",
            duration: 2.5
        )

        XCTAssertEqual(result.text, "Hello world")
        XCTAssertEqual(result.segments.count, 1)
        XCTAssertEqual(result.language, "en")
        XCTAssertEqual(result.duration, 2.5)
    }

    func testTranscriptionSegment_id() {
        let segment = TranscriptionSegment(text: "Test", start: 1.0, end: 3.0)
        XCTAssertEqual(segment.id, "1.0-3.0")
    }

    // MARK: - CommentVariant Model

    func testCommentVariant_decodesFromJSON() throws {
        let json = """
        {
            "id": "v1",
            "label": "Diplomatic",
            "axes": {"directness": 0.3, "brevity": 0.5, "formality": 0.7, "rewrite_vs_comment": 0.0},
            "text": "Consider revising for clarity."
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let variant = try JSONDecoder().decode(CommentVariant.self, from: data)

        XCTAssertEqual(variant.id, "v1")
        XCTAssertEqual(variant.label, "Diplomatic")
        XCTAssertEqual(variant.text, "Consider revising for clarity.")
        XCTAssertEqual(variant.axes.directness, 0.3, accuracy: 0.01)
    }

    // MARK: - PreferenceAxes

    func testPreferenceAxes_default() {
        let axes = PreferenceAxes.default
        XCTAssertEqual(axes.directness, 0.5)
        XCTAssertEqual(axes.brevity, 0.5)
        XCTAssertEqual(axes.formality, 0.5)
        XCTAssertEqual(axes.rewriteVsComment, 0.0)
    }

    func testPreferenceAxes_promptFragment() {
        let axes = PreferenceAxes(directness: 0.8, brevity: 0.2, formality: 0.1, rewriteVsComment: 0.9)
        let fragment = axes.asPromptFragment

        XCTAssertTrue(fragment.contains("Directness"))
        XCTAssertTrue(fragment.contains("0.8"))
        XCTAssertTrue(fragment.contains("direct"))
        XCTAssertTrue(fragment.contains("brief"))
        XCTAssertTrue(fragment.contains("formal"))
        XCTAssertTrue(fragment.contains("suggest rewrite"))
    }
}
