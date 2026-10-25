//
//  LyricTools.swift
//  octave
//

import Foundation

final class LyricTools {
    static func exportLRC(lines: [LyricLine]) -> String {
        var result = ""
        for line in lines {
            let m = Int(line.time) / 60
            let s = Int(line.time) % 60
            let cs = Int((line.time.truncatingRemainder(dividingBy: 1.0)) * 100)
            result += String(format: "[%02d:%02d.%02d]%@\n", m, s, cs, line.text)
        }
        return result
    }
}
