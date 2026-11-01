import SwiftUI

struct ModelDownloadView: View {
    @Environment(ModelDownloadManager.self) private var downloadManager

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Welcome to Draftsmith")
                .font(.title)

            Text("Draftsmith needs to download an AI language model and grammar engine. This only happens once.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let warning = SystemCapabilities.current.recommendedModelConfig().modelSizeWarning {
                Label(warning, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if downloadManager.isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: downloadManager.downloadProgress)
                    Text(downloadManager.currentDownloadDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 16) {
                    Button("Set Up Now") {
                        Task {
                            await downloadManager.downloadModels(
                                recommendation: SystemCapabilities.current.recommendedModelConfig()
                            )
                            onComplete()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Skip for Now") {
                        downloadManager.skipDownload()
                        onComplete()
                    }
                }
            }

            if let error = downloadManager.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(40)
        .frame(width: 500)
    }
}
