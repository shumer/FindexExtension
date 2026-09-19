import Foundation

public enum TemplateRendering {
    public static func render(_ data: Data, values: [String: String]) -> Data {
        let encoding: String.Encoding
        let prefix: Data
        if data.starts(with: [0xff, 0xfe]) { encoding = .utf16LittleEndian; prefix = Data([0xff, 0xfe]) }
        else if data.starts(with: [0xfe, 0xff]) { encoding = .utf16BigEndian; prefix = Data([0xfe, 0xff]) }
        else { encoding = .utf8; prefix = data.starts(with: [0xef, 0xbb, 0xbf]) ? Data([0xef, 0xbb, 0xbf]) : Data() }
        guard let text = String(data: data.dropFirst(prefix.count), encoding: encoding), !text.contains("\0"),
              let pattern = try? NSRegularExpression(pattern: "\\{\\{(date|datetime|filename|author|year|uuid)\\}\\}") else { return data }
        let mutable = NSMutableString(string: text)
        for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range(at: 1), in: text), let replacement = values[String(text[range])] else { continue }
            mutable.replaceCharacters(in: match.range, with: replacement)
        }
        guard let result = (mutable as String).data(using: encoding) else { return data }
        return prefix + result
    }
}
