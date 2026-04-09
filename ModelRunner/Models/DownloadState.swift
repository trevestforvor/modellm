import Foundation

enum DownloadState: Equatable {
    case idle
    case downloading(modelName: String, progress: Double, bytesWritten: Int64, totalBytes: Int64, throughput: Double?)
    case paused(modelName: String, bytesWritten: Int64)
    case failed(modelName: String, errorDescription: String)

    var isActive: Bool {
        if case .downloading = self { return true }
        if case .paused = self { return true }
        return false
    }

    var modelName: String? {
        switch self {
        case .idle: return nil
        case .downloading(let name, _, _, _, _): return name
        case .paused(let name, _): return name
        case .failed(let name, _): return name
        }
    }
}
