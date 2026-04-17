import Foundation

enum ChatContentPart: Identifiable, Equatable {
    case markdown(id: String, text: String)
    case visualization(id: String, spec: VisualizationSpec)

    var id: String {
        switch self {
        case .markdown(let id, _): return id
        case .visualization(let id, _): return id
        }
    }
}

enum ChatContentParser {
    /// Splits message content into markdown chunks and JSON visualization blocks (```json ... ```).
    static func parse(_ content: String) -> [ChatContentPart] {
        let text = content
        if text.isEmpty { return [] }

        // Regex: ```json <anything> ```
        let pattern = #"```json\s*([\s\S]*?)\s*```"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [.markdown(id: UUID().uuidString, text: text)]
        }

        let ns = text as NSString
        let matches = re.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        if matches.isEmpty {
            return [.markdown(id: UUID().uuidString, text: text)]
        }

        var parts: [ChatContentPart] = []
        var cursor = 0

        for m in matches {
            let full = m.range(at: 0)
            let inner = m.range(at: 1)

            if full.location > cursor {
                let chunk = ns.substring(with: NSRange(location: cursor, length: full.location - cursor))
                if !chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    parts.append(.markdown(id: UUID().uuidString, text: chunk))
                }
            }

            let jsonString = ns.substring(with: inner)
            if let spec = VisualizationSpec.decode(from: jsonString) {
                parts.append(.visualization(id: UUID().uuidString, spec: spec))
            } else {
                // If JSON doesn't decode, keep it visible as code-fenced markdown.
                parts.append(.markdown(id: UUID().uuidString, text: "```json\n\(jsonString)\n```"))
            }

            cursor = full.location + full.length
        }

        if cursor < ns.length {
            let tail = ns.substring(from: cursor)
            if !tail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append(.markdown(id: UUID().uuidString, text: tail))
            }
        }

        return parts
    }
}

