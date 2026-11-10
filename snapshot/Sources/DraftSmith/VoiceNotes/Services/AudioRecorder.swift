import Foundation
import AVFoundation

@Observable
@MainActor
final class AudioRecorder: NSObject, AudioRecorderProtocol {
    private(set) var isRecording = false
    private(set) var elapsedTime: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var currentAnnotationUUID: UUID?
    private var recordingStartTime: Date?
    private var timer: Timer?

    func startRecording(annotationUUID: UUID) throws {
        // Check microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
            throw DraftSmithError.audioPermissionDenied
        case .denied, .restricted:
            throw DraftSmithError.audioPermissionDenied
        @unknown default:
            throw DraftSmithError.audioPermissionDenied
        }

        let directory = AppDirectories.audioDirectory(for: annotationUUID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileURL = directory.appendingPathComponent("\(timestamp).wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: AppConstants.audioSampleRate,
            AVNumberOfChannelsKey: AppConstants.audioChannels,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record()
            currentAnnotationUUID = annotationUUID
            recordingStartTime = Date()
            isRecording = true
            elapsedTime = 0

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self, let start = self.recordingStartTime else { return }
                    self.elapsedTime = Date().timeIntervalSince(start)
                }
            }
        } catch {
            throw DraftSmithError.audioRecordingFailed(error.localizedDescription)
        }
    }

    func stopRecording() -> AudioRecording? {
        guard let recorder = audioRecorder, isRecording else { return nil }

        recorder.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false

        guard let uuid = currentAnnotationUUID, let startTime = recordingStartTime else {
            return nil
        }

        let duration = Date().timeIntervalSince(startTime)
        let recording = AudioRecording(
            url: recorder.url,
            duration: duration,
            annotationUUID: uuid
        )

        audioRecorder = nil
        currentAnnotationUUID = nil
        recordingStartTime = nil

        return recording
    }
}
