import Foundation

// MARK: - Pipeline

/// Pipeline run request body.
struct PipelineRunRequest: Codable, Sendable {
    var stage: String = "full"
}

/// Pipeline run response.
struct PipelineRunResponse: Codable, Sendable {
    let status: String
    let message: String
}

struct PipelinePhase: Codable, Sendable, Identifiable {
    let name: String
    let status: String
    let totalItems: Int
    let completedItems: Int
    let currentStep: String
    let currentItem: String
    let elapsedSeconds: Double
    let summary: String
    let error: String

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, status, summary, error
        case totalItems = "total_items"
        case completedItems = "completed_items"
        case currentStep = "current_step"
        case currentItem = "current_item"
        case elapsedSeconds = "elapsed_seconds"
    }
}

/// Pipeline progress from `/api/sync/status`.
struct PipelineStatus: Codable, Sendable {
    let status: String
    let runId: String?
    let currentPhase: String?
    let elapsedSeconds: Double?
    let ageSeconds: Double?
    let trigger: String?
    let phases: [PipelinePhase]

    var running: Bool {
        status.lowercased() == "running"
    }

    var activePhase: PipelinePhase? {
        if let currentPhase {
            return phases.first(where: { $0.name == currentPhase })
        }
        return phases.first(where: { $0.status == "running" })
    }

    enum CodingKeys: String, CodingKey {
        case status, trigger, phases
        case runId = "run_id"
        case currentPhase = "current_phase"
        case elapsedSeconds = "elapsed_seconds"
        case ageSeconds = "age_seconds"
    }
}

// MARK: - Workflows

/// Request to submit Plaud AI workflows.
struct WorkflowSubmitRequest: Codable, Sendable {
    var daysBack: Int = 30
    var limit: Int = 50
    var templateId: String?
    var model: String = "gemini"

    enum CodingKeys: String, CodingKey {
        case daysBack = "days_back"
        case limit
        case templateId = "template_id"
        case model
    }
}

/// Request to refresh workflow statuses.
struct WorkflowRefreshRequest: Codable, Sendable {
    var daysBack: Int = 60
    var limit: Int = 50

    enum CodingKeys: String, CodingKey {
        case daysBack = "days_back"
        case limit
    }
}

/// Request to run a workflow on a single recording.
struct RecordingWorkflowRequest: Codable, Sendable {
    var templateId: String?
    var model: String = "gemini"

    enum CodingKeys: String, CodingKey {
        case templateId = "template_id"
        case model
    }
}

/// Category override request.
struct CategoryOverrideRequest: Codable, Sendable {
    let category: String
}

/// Generic success response.
struct SuccessResponse: Codable, Sendable {
    let success: Bool
    let message: String
}
