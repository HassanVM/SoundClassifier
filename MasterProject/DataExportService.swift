// DataExportService.swift
// CREATE NEW FILE: Right-click MasterProject folder → New File → Swift File → "DataExportService"

import Foundation
import UIKit

final class DataExportService {

    static let shared = DataExportService()
    private init() {}

    // MARK: - Save to Documents

    func saveToDocuments(_ export: SessionDataExport) throws -> URL {
        let data = try export.toJSON()
        let filename = "session_\(export.metadata.sessionID)_\(dateString()).json"
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL
    }

    func savedSessionFiles() -> [URL] {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let files = try? FileManager.default.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: nil)
        return files?.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent } ?? []
    }

    func deleteFile(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - CSV Export

    func responseEventsCSV(_ responses: [ResponseEventLog]) -> String {
        var csv = "id,timestamp,session_timestamp,category,intensity,is_target,reaction_time_ms,did_tap,classification,condition,block\n"
        for r in responses {
            csv += "\(r.id),\(r.timestamp.ISO8601Format()),\(r.sessionTimestamp),"
            csv += "\(r.displayedCategory?.rawValue ?? "unknown"),\(r.displayedIntensity?.rawValue ?? "unknown"),"
            csv += "\(r.isTarget),\(r.reactionTimeMs.map { String(format: "%.1f", $0) } ?? "NA"),"
            csv += "\(r.didTap),\(r.classification.rawValue),\(r.activeCondition.code),\(r.blockNumber)\n"
        }
        return csv
    }

    // MARK: - Share

    @MainActor
    func shareFiles(_ urls: [URL]) {
        let activityVC = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        if let vc = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first?.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = vc.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
            vc.present(activityVC, animated: true)
        }
    }

    private func dateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return f.string(from: Date())
    }
}
