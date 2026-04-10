import Foundation

/// A recording eligible for Plaud cloud upload.
struct UploadCandidate: Codable, Identifiable, Sendable {
    let recordingId: String
    let title: String?
    let durationSeconds: Double?
    let status: String?

    var id: String { recordingId }

    enum CodingKeys: String, CodingKey {
        case recordingId = "recording_id"
        case title
        case durationSeconds = "duration_seconds"
        case status
    }
}

/// Response wrapper for upload candidates.
struct UploadCandidatesResponse: Codable, Sendable {
    let recordings: [UploadCandidate]
}
