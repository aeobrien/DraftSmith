import Foundation

@MainActor
protocol AudioRecorderProtocol {
    var isRecording: Bool { get }
    func startRecording(annotationUUID: UUID) throws
    func stopRecording() -> AudioRecording?
}
