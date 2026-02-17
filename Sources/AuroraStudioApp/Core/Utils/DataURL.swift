import Foundation

struct DataURL {
    let mimeType: String
    let base64Data: String

    var encoded: String {
        "data:\(mimeType);base64,\(base64Data)"
    }

    init(mimeType: String, base64Data: String) {
        self.mimeType = mimeType
        self.base64Data = base64Data
    }

    init?(rawValue: String) {
        guard rawValue.hasPrefix("data:"), let separator = rawValue.range(of: ";base64,") else {
            return nil
        }

        let mimeStart = rawValue.index(rawValue.startIndex, offsetBy: 5)
        let mime = String(rawValue[mimeStart..<separator.lowerBound])
        let base64 = String(rawValue[separator.upperBound...])

        guard !mime.isEmpty, !base64.isEmpty else { return nil }

        self.mimeType = mime
        self.base64Data = base64
    }

    func decodeData() -> Data? {
        Data(base64Encoded: base64Data)
    }
}
