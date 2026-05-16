import PDFKit
import Foundation

enum PDFReader {
    static func read(_ url: URL) -> String? {
        guard let doc = PDFDocument(url: url) else { return nil }
        return (0..<doc.pageCount)
            .compactMap { doc.page(at: $0)?.string }
            .joined(separator: "\n")
    }
}
