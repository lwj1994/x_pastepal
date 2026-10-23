import Foundation

public enum TextTransformation: String, CaseIterable, Identifiable, Sendable {
    case trim
    case removeEmptyLines
    case uppercase
    case lowercase
    case cleanURL

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .trim: return "去除首尾空白"
        case .removeEmptyLines: return "去除空行"
        case .uppercase: return "转换为大写"
        case .lowercase: return "转换为小写"
        case .cleanURL: return "移除链接跟踪参数"
        }
    }

    public func apply(to text: String) -> String {
        switch self {
        case .trim:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .removeEmptyLines:
            return text.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .joined(separator: "\n")
        case .uppercase:
            return text.uppercased()
        case .lowercase:
            return text.lowercased()
        case .cleanURL:
            let candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !candidate.contains(where: \.isWhitespace),
                  var components = URLComponents(string: candidate),
                  ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
                  components.host != nil,
                  let query = components.percentEncodedQuery else { return text }
            // 保留其余参数的编码、次序和重复键，避免改变带签名链接的正文。
            let parameters = query.components(separatedBy: "&")
            let retained = parameters.filter { parameter in
                let encodedName = String(parameter.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)[0])
                let name = (encodedName.removingPercentEncoding ?? encodedName).lowercased()
                return !name.hasPrefix("utm_") && !Self.trackingParameters.contains(name)
            }
            guard retained.count != parameters.count else { return text }
            components.percentEncodedQuery = retained.isEmpty ? nil : retained.joined(separator: "&")
            return components.string ?? text
        }
    }

    private static let trackingParameters: Set<String> = [
        "fbclid", "gclid", "dclid", "msclkid", "twclid", "ttclid", "yclid",
        "mc_cid", "mc_eid", "_hsenc", "_hsmi", "igshid", "igsh", "vero_id", "wickedid"
    ]
}
