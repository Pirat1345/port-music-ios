//
//  LyricsSync.swift
//  octave
//

import Foundation

final class LyricsSync {
    static func parseLRC(content: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let regex = try? NSRegularExpression(pattern: "\\[(\\d{1,2}):(\\d{2})(?:[.:](\\d{1,3}))?\\](.*)")
        
        content.enumerateLines { line, _ in
            let nsLine = line as NSString
            if let match = regex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                let mins = Double(nsLine.substring(with: match.range(at: 1))) ?? 0
                let secs = Double(nsLine.substring(with: match.range(at: 2))) ?? 0
                let text = nsLine.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
                let time = mins * 60 + secs
                lines.append(LyricLine(time: time, text: text))
            }
        }
        return lines
    }
}
