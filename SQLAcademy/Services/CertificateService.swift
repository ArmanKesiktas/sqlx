import Foundation
import UIKit

final class CertificateService {
    func makeRecord(
        packageID: String,
        interestID: String,
        packageTitle: String,
        lessonTitle: String,
        displayName: String,
        masteryScore: Int,
        summarySQL: [String],
        issuedAt: Date = Date()
    ) -> CertificateRecord {
        let safeName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Student" : displayName
        return CertificateRecord(
            id: UUID().uuidString,
            packageID: packageID,
            interestID: interestID,
            title: "SQLX Mastery Certificate",
            subtitle: "\(safeName) • \(packageTitle) • \(lessonTitle)",
            masteryScore: masteryScore,
            issuedAt: issuedAt,
            summarySQL: summarySQL
        )
    }

    func makeCertificatePDF(record: CertificateRecord) -> Data? {
        let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        return renderer.pdfData { context in
            context.beginPage()
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            let codeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.black
            ]

            let title = NSString(string: record.title)
            title.draw(at: CGPoint(x: 48, y: 72), withAttributes: titleAttrs)

            let subtitle = NSString(string: record.subtitle)
            subtitle.draw(at: CGPoint(x: 48, y: 126), withAttributes: bodyAttrs)

            let score = NSString(string: "Mastery Score: \(record.masteryScore)%")
            score.draw(at: CGPoint(x: 48, y: 156), withAttributes: bodyAttrs)

            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            let issued = NSString(string: "Issued: \(formatter.string(from: record.issuedAt))")
            issued.draw(at: CGPoint(x: 48, y: 186), withAttributes: bodyAttrs)

            let heading = NSString(string: "Project Summary SQL")
            heading.draw(at: CGPoint(x: 48, y: 240), withAttributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: UIColor.black
            ])

            var y: CGFloat = 278
            for sql in record.summarySQL.prefix(8) {
                let line = NSString(string: "• \(sql)")
                line.draw(with: CGRect(x: 56, y: y, width: 490, height: 48), options: [.usesLineFragmentOrigin], attributes: codeAttrs, context: nil)
                y += 38
            }
        }
    }

    func writeTemporaryPDF(_ data: Data, fileName: String) -> URL? {
        let safeName = fileName.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).pdf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func writeTemporaryJSON(_ data: Data, fileName: String) -> URL? {
        let safeName = fileName.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
