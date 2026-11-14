import SwiftUI
import Combine

// MARK: - Toy Metadata
public struct ToyMeta: Identifiable, Equatable {
    public let id: String
    public let label: String
    public let baseWidth: CGFloat
    public let accentColor: Color

    public init(id: String, label: String, baseWidth: CGFloat, accentColor: Color) {
        self.id = id
        self.label = label
        self.baseWidth = baseWidth
        self.accentColor = accentColor
    }

    public static let all: [ToyMeta] = [
        ToyMeta(id: "duck", label: "Gelbe Ente", baseWidth: 96, accentColor: Color(hex: "#ffd60a")),
        ToyMeta(id: "bear", label: "Teddybär", baseWidth: 92, accentColor: Color(hex: "#c89b7b")),
        ToyMeta(id: "panda", label: "Panda", baseWidth: 86, accentColor: Color(hex: "#e5e5ea")),
        ToyMeta(id: "bunny", label: "Häschen", baseWidth: 78, accentColor: Color(hex: "#fca5a5")),
        ToyMeta(id: "dino", label: "Dinosaurier", baseWidth: 92, accentColor: Color(hex: "#86efac")),
        ToyMeta(id: "penguin", label: "Pinguin", baseWidth: 84, accentColor: Color(hex: "#93c5fd")),
        ToyMeta(id: "fox", label: "Fuchs", baseWidth: 80, accentColor: Color(hex: "#fdba74")),
        ToyMeta(id: "frog", label: "Frosch", baseWidth: 76, accentColor: Color(hex: "#4ade80")),
        ToyMeta(id: "whale", label: "Wal", baseWidth: 90, accentColor: Color(hex: "#67e8f9")),
        ToyMeta(id: "cat", label: "Katze", baseWidth: 74, accentColor: Color(hex: "#fde047")),
        ToyMeta(id: "puppy", label: "Hündchen", baseWidth: 72, accentColor: Color(hex: "#f9a8d4")),
        ToyMeta(id: "unicorn", label: "Einhorn", baseWidth: 82, accentColor: Color(hex: "#d8b4fe"))
    ]

    public static func meta(for id: String) -> ToyMeta {
        all.first(where: { $0.id == id }) ?? ToyMeta(id: id, label: id.capitalized, baseWidth: 84, accentColor: .white)
    }
}

// MARK: - Color Hex Extension
extension Color {
    public init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Compact SVG Path Parser for Claw Vector Art
public struct SVGPathParser {
    public static func parse(d: String) -> Path {
        var path = Path()
        var currentPoint = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControlPoint: CGPoint? = nil

        let tokens = tokenize(d)
        var i = 0

        func nextNumber() -> CGFloat? {
            guard i < tokens.count else { return nil }
            if case .number(let val) = tokens[i] {
                i += 1
                return val
            }
            return nil
        }

        while i < tokens.count {
            guard case .command(let cmd) = tokens[i] else {
                i += 1
                continue
            }
            i += 1

            switch cmd {
            case "M":
                if let x = nextNumber(), let y = nextNumber() {
                    currentPoint = CGPoint(x: x, y: y)
                    subpathStart = currentPoint
                    path.move(to: currentPoint)
                    while let nextX = nextNumber(), let nextY = nextNumber() {
                        currentPoint = CGPoint(x: nextX, y: nextY)
                        path.addLine(to: currentPoint)
                    }
                }
            case "m":
                if let dx = nextNumber(), let dy = nextNumber() {
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    subpathStart = currentPoint
                    path.move(to: currentPoint)
                    while let nextDx = nextNumber(), let nextDy = nextNumber() {
                        currentPoint = CGPoint(x: currentPoint.x + nextDx, y: currentPoint.y + nextDy)
                        path.addLine(to: currentPoint)
                    }
                }
            case "L":
                while let x = nextNumber(), let y = nextNumber() {
                    currentPoint = CGPoint(x: x, y: y)
                    path.addLine(to: currentPoint)
                }
            case "l":
                while let dx = nextNumber(), let dy = nextNumber() {
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    path.addLine(to: currentPoint)
                }
            case "H":
                while let x = nextNumber() {
                    currentPoint = CGPoint(x: x, y: currentPoint.y)
                    path.addLine(to: currentPoint)
                }
            case "h":
                while let dx = nextNumber() {
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y)
                    path.addLine(to: currentPoint)
                }
            case "V":
                while let y = nextNumber() {
                    currentPoint = CGPoint(x: currentPoint.x, y: y)
                    path.addLine(to: currentPoint)
                }
            case "v":
                while let dy = nextNumber() {
                    currentPoint = CGPoint(x: currentPoint.x, y: currentPoint.y + dy)
                    path.addLine(to: currentPoint)
                }
            case "C":
                while let x1 = nextNumber(), let y1 = nextNumber(),
                      let x2 = nextNumber(), let y2 = nextNumber(),
                      let x = nextNumber(), let y = nextNumber() {
                    let cp1 = CGPoint(x: x1, y: y1)
                    let cp2 = CGPoint(x: x2, y: y2)
                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = cp2
                    path.addCurve(to: currentPoint, control1: cp1, control2: cp2)
                }
            case "c":
                while let dx1 = nextNumber(), let dy1 = nextNumber(),
                      let dx2 = nextNumber(), let dy2 = nextNumber(),
                      let dx = nextNumber(), let dy = nextNumber() {
                    let cp1 = CGPoint(x: currentPoint.x + dx1, y: currentPoint.y + dy1)
                    let cp2 = CGPoint(x: currentPoint.x + dx2, y: currentPoint.y + dy2)
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    lastControlPoint = cp2
                    path.addCurve(to: currentPoint, control1: cp1, control2: cp2)
                }
            case "S", "s":
                let isRelative = (cmd == "s")
                while let x2 = nextNumber(), let y2 = nextNumber(),
                      let x = nextNumber(), let y = nextNumber() {
                    let cp1: CGPoint
                    if let prevCp = lastControlPoint {
                        cp1 = CGPoint(x: 2 * currentPoint.x - prevCp.x, y: 2 * currentPoint.y - prevCp.y)
                    } else {
                        cp1 = currentPoint
                    }
                    let cp2 = isRelative ? CGPoint(x: currentPoint.x + x2, y: currentPoint.y + y2) : CGPoint(x: x2, y: y2)
                    currentPoint = isRelative ? CGPoint(x: currentPoint.x + x, y: currentPoint.y + y) : CGPoint(x: x, y: y)
                    lastControlPoint = cp2
                    path.addCurve(to: currentPoint, control1: cp1, control2: cp2)
                }
            case "Z", "z":
                path.closeSubpath()
                currentPoint = subpathStart
                lastControlPoint = nil
            default:
                break
            }
        }
        return path
    }

    private enum Token {
        case command(Character)
        case number(CGFloat)
    }

    private static func tokenize(_ d: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(d)
        var idx = 0

        while idx < chars.count {
            let ch = chars[idx]
            if ch.isWhitespace || ch == "," {
                idx += 1
                continue
            }
            if ch.isLetter {
                tokens.append(.command(ch))
                idx += 1
                continue
            }
            if ch == "-" || ch == "+" || ch == "." || ch.isNumber {
                var numStr = String(ch)
                idx += 1
                var hasDot = (ch == ".")
                while idx < chars.count {
                    let c = chars[idx]
                    if c.isNumber {
                        numStr.append(c)
                        idx += 1
                    } else if c == "." && !hasDot {
                        hasDot = true
                        numStr.append(c)
                        idx += 1
                    } else if c == "e" || c == "E" {
                        numStr.append(c)
                        idx += 1
                        if idx < chars.count && (chars[idx] == "+" || chars[idx] == "-") {
                            numStr.append(chars[idx])
                            idx += 1
                        }
                    } else {
                        break
                    }
                }
                if let val = Double(numStr) {
                    tokens.append(.number(CGFloat(val)))
                }
                continue
            }
            idx += 1
        }
        return tokens
    }
}

// MARK: - Vector Claw Artwork Paths
private struct ClawVectorData {
    static let pivot = CGPoint(x: 20.6, y: 22.7)

    static let bodyPaths: [(Color, Path)] = [
        (Color(hex: "#666D85"), SVGPathParser.parse(d: "M20.031,24.324c0.086,2.939,0.263,5.874,0.531,8.802c0.016,0.175,0.073,0.395,0.247,0.42c0.218,0.03,0.311-0.267,0.318-0.487c0.104-2.988,0.207-5.975,0.311-8.963C21.048,24.142,20.657,24.188,20.031,24.324z")),
        (Color(hex: "#3D4459"), SVGPathParser.parse(d: "M20.222,11.816c0.023,2.291,0.046,4.583,0.069,6.874c0.356,0.036,0.717,0.036,1.073,0c-0.01-2.339-0.019-4.679-0.028-7.018C20.987,11.656,20.636,11.679,20.222,11.816z")),
        (Color(hex: "#666D85"), SVGPathParser.parse(d: "M18.924,10.588c0.013,0.395,0.025,0.789,0.038,1.184c0.003,0.101,0.009,0.209,0.073,0.288c0.084,0.103,0.234,0.116,0.367,0.12c1.017,0.034,2.044,0.068,3.047-0.106c0.054-0.009,0.111-0.021,0.15-0.059c0.047-0.047,0.054-0.12,0.058-0.187c0.022-0.45,0.009-0.901-0.039-1.349c-0.004-0.04-0.011-0.083-0.04-0.11c-0.031-0.03-0.079-0.031-0.122-0.031C21.186,10.343,19.916,10.39,18.924,10.588z")),
        (Color(hex: "#DE2121"), SVGPathParser.parse(d: "M18.282,9.052c-0.062,0-0.13,0.002-0.179,0.04c-0.059,0.045-0.074,0.126-0.084,0.199c-0.055,0.411-0.06,0.83-0.015,1.242c0.008,0.074,0.02,0.153,0.071,0.208c0.066,0.07,0.172,0.077,0.268,0.079c1.573,0.031,3.146,0.006,4.717-0.076c0.064-0.003,0.132-0.008,0.185-0.045c0.096-0.066,0.102-0.204,0.098-0.321c-0.015-0.438-0.031-0.875-0.046-1.313c-0.001-0.039-0.004-0.081-0.031-0.109c-0.029-0.03-0.076-0.032-0.119-0.032C22.905,8.925,19.701,9.046,18.282,9.052z")),
        (Color(hex: "#666D85"), SVGPathParser.parse(d: "M19.815,20.079c-0.001-0.526-0.003-1.052-0.004-1.577c0-0.036,0-0.074,0.017-0.105c0.033-0.061,0.112-0.077,0.18-0.085c0.483-0.058,0.97-0.086,1.456-0.083c0.099,0.001,0.21,0.008,0.274,0.083c0.053,0.062,0.055,0.151,0.055,0.233c0,0.475-0.001,0.95-0.001,1.425C21.155,19.978,20.517,19.972,19.815,20.079z")),
        (Color(hex: "#B4B9C4"), SVGPathParser.parse(d: "M19.458,20.771c-0.269,0.791-0.539,1.583-0.808,2.374c-0.016,0.048-0.033,0.098-0.022,0.147c0.01,0.047,0.045,0.085,0.077,0.121l0.799,0.87c0.083,0.091,0.169,0.184,0.28,0.238c0.134,0.066,0.289,0.068,0.438,0.069c0.471,0.003,0.942,0.006,1.413,0.01c0.048,0,0.098,0,0.141-0.021c0.052-0.026,0.085-0.078,0.115-0.127c0.244-0.399,0.487-0.797,0.731-1.196c0.047-0.078,0.096-0.159,0.106-0.249c0.011-0.101-0.027-0.199-0.065-0.293c-0.231-0.58-0.463-1.159-0.695-1.739c-0.029-0.072-0.061-0.149-0.124-0.194c-0.074-0.053-0.172-0.051-0.262-0.047C20.836,20.765,20.09,20.808,19.458,20.771z")),
        (Color(hex: "#3D4459"), SVGPathParser.parse(d: "M21.101,22.267c-0.117-0.169-0.332-0.237-0.531-0.186c-0.182,0.047-0.359,0.12-0.459,0.274c-0.076,0.116-0.095,0.259-0.101,0.397c-0.004,0.095-0.002,0.192,0.034,0.28c0.061,0.149,0.214,0.245,0.372,0.274c0.254,0.047,0.53-0.066,0.678-0.278c0.147-0.212,0.158-0.51,0.025-0.732C21.114,22.286,21.107,22.276,21.101,22.267z")),
        (Color(hex: "#DE2121"), SVGPathParser.parse(d: "M22.585,19.777c-1.368-0.115-2.751-0.055-4.105,0.179c-0.127,0.022-0.272,0.059-0.327,0.176c-0.028,0.06-0.025,0.129-0.022,0.195c0.009,0.173,0.017,0.345,0.026,0.518c0.003,0.058,0.007,0.118,0.037,0.167c0.053,0.084,0.164,0.106,0.262,0.118c1.395,0.173,2.808,0.083,4.21-0.007c0.351-0.023,0.703-0.045,1.047-0.121c0.053-0.012,0.109-0.026,0.145-0.066c0.044-0.048,0.049-0.119,0.05-0.184c0.003-0.209-0.01-0.418-0.039-0.625c-0.01-0.07-0.025-0.145-0.076-0.193c-0.048-0.045-0.118-0.055-0.183-0.064C23.273,19.826,22.935,19.806,22.585,19.777z")),
        (Color(hex: "#851313"), SVGPathParser.parse(d: "M20.275,21.326c-0.53,0-1.06-0.021-1.589-0.064c-0.113-0.009-0.267-0.021-0.391-0.104c-0.281-0.187-0.251-0.584-0.204-0.866c0.007-0.041,0.046-0.068,0.086-0.061c0.041,0.007,0.068,0.045,0.062,0.086c-0.064,0.383-0.02,0.611,0.139,0.716c0.085,0.056,0.195,0.069,0.32,0.079c1.626,0.13,3.266,0.058,4.875-0.214c0.041-0.007,0.079,0.021,0.086,0.061c0.007,0.041-0.021,0.08-0.061,0.087C22.501,21.233,21.388,21.326,20.275,21.326z")),
        (Color(hex: "#1F2229"), SVGPathParser.parse(d: "M20.376,17.8c-0.04,0-0.074-0.032-0.075-0.073l-0.152-5.054c-0.001-0.041,0.031-0.076,0.073-0.077c0.042,0,0.076,0.031,0.077,0.073l0.152,5.054c0.001,0.042-0.031,0.076-0.073,0.077C20.377,17.8,20.376,17.8,20.376,17.8z"))
    ]

    static let armLPaths: [(Color, Path)] = [
        (Color(hex: "#808596"), SVGPathParser.parse(d: "M18.965,20.803c-1.243,0.927-2.486,1.854-3.729,2.781c-0.176,0.131-0.363,0.279-0.417,0.491c-0.049,0.192,0.023,0.391,0.089,0.577c0.681,1.927,0.824,3.999,1.323,5.981c0.055,0.217,0.118,0.441,0.261,0.613c0.142,0.17,0.348,0.272,0.542,0.38c0.641,0.359,1.208,0.848,1.658,1.429c0.141,0.182,0.283,0.383,0.499,0.463c0.216,0.08,0.52-0.043,0.533-0.249c-0.459-0.883-1.167-1.635-2.02-2.147c-0.152-0.091-0.313-0.179-0.413-0.325c-0.081-0.119-0.113-0.263-0.142-0.404c-0.348-1.641-0.697-3.281-1.045-4.922c-0.102-0.478,0.135-0.964,0.574-1.178c0.616-0.3,1.225-0.615,1.827-0.943c0.325-0.177,0.656-0.367,0.882-0.66c0.274-0.355,0.358-0.817,0.433-1.259c0.029-0.17,0.057-0.35-0.007-0.51c-0.096-0.238-0.378-0.358-0.635-0.345C18.921,20.591,18.683,20.709,18.965,20.803z")),
        (Color(hex: "#3D4459"), SVGPathParser.parse(d: "M19.335,32.718c-0.024,0-0.047-0.011-0.062-0.032c-0.347-0.498-0.802-0.934-1.314-1.26c-0.033-0.021-0.067-0.042-0.101-0.063c-0.213-0.132-0.432-0.268-0.574-0.485c-0.11-0.169-0.158-0.367-0.2-0.543c-0.391-1.627-0.752-3.283-1.073-4.922c-0.032-0.163-0.076-0.387,0.009-0.583c0.093-0.216,0.315-0.338,0.477-0.427l1.805-0.99c0.036-0.02,0.082-0.007,0.102,0.03c0.02,0.036,0.007,0.082-0.03,0.102l-1.805,0.99c-0.185,0.102-0.344,0.199-0.412,0.355c-0.061,0.141-0.036,0.307,0.001,0.494c0.321,1.638,0.681,3.292,1.072,4.916c0.039,0.163,0.084,0.349,0.18,0.496c0.123,0.188,0.328,0.316,0.527,0.439c0.034,0.021,0.068,0.042,0.102,0.064c0.529,0.336,0.998,0.786,1.357,1.3c0.024,0.034,0.015,0.081-0.019,0.104C19.365,32.714,19.35,32.718,19.335,32.718z"))
    ]

    static let armRPaths: [(Color, Path)] = [
        (Color(hex: "#808596"), SVGPathParser.parse(d: "M22.64,20.803c1.243,0.927,2.486,1.854,3.729,2.781c0.176,0.131,0.363,0.279,0.417,0.491c0.049,0.192-0.023,0.391-0.089,0.577c-0.681,1.927-0.824,3.999-1.323,5.981c-0.055,0.217-0.118,0.441-0.261,0.613c-0.142,0.17-0.348,0.272-0.542,0.38c-0.641,0.359-1.208,0.848-1.658,1.429c-0.141,0.182-0.284,0.383-0.499,0.463c-0.216,0.08-0.52-0.043-0.533-0.249c0.459-0.883,1.167-1.635,2.02-2.147c0.152-0.091,0.313-0.179,0.413-0.325c0.081-0.119,0.113-0.263,0.142-0.404c0.348-1.641,0.697-3.281,1.045-4.922c0.101-0.478-0.135-0.964-0.574-1.178c-0.616-0.3-1.225-0.615-1.827-0.943c-0.324-0.177-0.656-0.367-0.882-0.66c-0.274-0.355-0.358-0.817-0.433-1.259c-0.029-0.17-0.057-0.35,0.007-0.51c0.096-0.238,0.378-0.358,0.635-0.345C22.684,20.591,22.922,20.709,22.64,20.803z")),
        (Color(hex: "#3D4459"), SVGPathParser.parse(d: "M24.41,30.372c-0.007,0-0.014-0.001-0.021-0.003c-0.04-0.012-0.063-0.053-0.051-0.093c0.464-1.586,0.83-3.218,1.089-4.85c0.007-0.041,0.045-0.069,0.086-0.062c0.041,0.007,0.069,0.045,0.062,0.086c-0.26,1.639-0.627,3.277-1.093,4.868C24.472,30.351,24.442,30.372,24.41,30.372z")),
        (Color(hex: "#3D4459"), SVGPathParser.parse(d: "M22.613,33.409c-0.017,0-0.034-0.006-0.048-0.017c-0.032-0.027-0.036-0.074-0.009-0.106c0.565-0.675,1.234-1.247,1.99-1.698l0.055-0.033c0.18-0.107,0.365-0.217,0.488-0.377c0.142-0.186,0.197-0.436,0.244-0.656l1.14-5.256c0.009-0.04,0.049-0.066,0.089-0.057c0.041,0.009,0.066,0.049,0.057,0.089l-1.14,5.256c-0.051,0.236-0.109,0.503-0.272,0.715c-0.141,0.184-0.339,0.301-0.531,0.415l-0.055,0.032c-0.741,0.443-1.398,1.003-1.952,1.666C22.656,33.399,22.635,33.409,22.613,33.409z"))
    ]
}

// MARK: - Coil Spring Cable Path
private struct CoilSpringShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midX = rect.midX
        p.move(to: CGPoint(x: midX, y: rect.minY))
        p.addLine(to: CGPoint(x: midX, y: rect.minY + rect.height * 0.05))

        let coils = 12
        for i in 0..<coils {
            let startY = rect.minY + rect.height * (0.05 + CGFloat(i) * 0.075)
            let endY = rect.minY + rect.height * (0.05 + CGFloat(i + 1) * 0.075)
            let isRight = (i % 2 == 0)
            let cpX = isRight ? rect.maxX : rect.minX
            p.addCurve(
                to: CGPoint(x: midX, y: endY),
                control1: CGPoint(x: cpX, y: startY + (endY - startY) * 0.25),
                control2: CGPoint(x: cpX, y: startY + (endY - startY) * 0.75)
            )
        }
        p.addLine(to: CGPoint(x: midX, y: rect.maxY))
        return p
    }
}

// MARK: - Soft-Body Pile Slot Data
public struct PileSlot: Identifiable {
    public let id: Int
    public let toyId: String
    public var w: CGFloat
    public var x: CGFloat
    public var b: CGFloat
    public var z: Int
    public var rot: Double
    public var dropFrom: CGFloat
    public var delay: Double
}

public struct SoftBodyState {
    public var dx: CGFloat = 0
    public var dy: CGFloat = 0
    public var rot: Double = 0
    public var sq: CGFloat = 0
    public var vdx: CGFloat = 0
    public var vdy: CGFloat = 0
    public var vrot: Double = 0
    public var vsq: CGFloat = 0
    public var ey: CGFloat = 0
    public var evy: CGFloat = 0
    public var delay: Double = 0
    public var landed: Bool = false
}

// MARK: - ClawMachineView
public struct ClawMachineView: View {
    public let targetId: String
    public let onVerify: (String) -> Void
    public let onFail: (() -> Void)?

    // Canvas geometry
    private let GW: CGFloat = 380.0
    private let GH: CGFloat = 320.0
    private let RAIL_Y: CGFloat = 14.0
    private let HOME_Y: CGFloat = 64.0
    private let DROP_Y: CGFloat = 198.0
    private let CLAW_MIN: CGFloat = 46.0
    private let CLAW_MAX: CGFloat = 334.0
    private let COIL_LEN: CGFloat = 50.0
    private let GRAB_RADIUS: CGFloat = 38.0
    private let GRIP_OFFSET: CGFloat = 46.0
    private let TRAY_CX: CGFloat = 232.0
    private let TRAY_CY: CGFloat = 376.0
    private let TRAY_MIN: CGFloat = 150.0
    private let TRAY_MAX: CGFloat = 320.0
    private let MOUTH_Y: CGFloat = 353.0
    private let DROP_G: CGFloat = 1150.0
    private let ENTRANCE_G: CGFloat = 1500.0

    // Lifecycle phases
    private enum Phase {
        case idle
        case seq
        case carry
        case toTray
        case celebrate
        case deny
        case done
    }

    private enum Stage {
        case none
        case antic
        case down
        case dwell1
        case close
        case dwell2
        case load
        case up
        case open
        case beat
        case shine
    }

    private enum TrayMode {
        case normal
        case hot
        case open
        case win
        case no
    }

    // Simulation states
    @State private var phase: Phase = .idle
    @State private var stage: Stage = .none
    @State private var stageTime: Double = 0.0
    @State private var clawX: CGFloat = 190.0
    @State private var clawY: CGFloat = 64.0
    @State private var vx: CGFloat = 0.0
    @State private var drive: CGFloat = 0.0
    @State private var sway: Double = 0.0
    @State private var swayV: Double = 0.0
    @State private var breeze: Double = 0.0
    @State private var clawClose: Double = 0.0
    @State private var carriedIndex: Int = -1
    @State private var carryPos: CGPoint = .zero
    @State private var carriedRot: Double = 0.0
    @State private var depthY: CGFloat = 198.0
    @State private var fallV: CGFloat = 0.0
    @State private var stretch: CGFloat = 0.0
    @State private var swallow: Double = 0.0
    @State private var isReleased: Bool = false
    @State private var overTray: Bool = false
    @State private var trayMode: TrayMode = .normal
    @State private var statusMessage: String? = nil
    @State private var isVerified: Bool = false

    // Input steering
    @State private var steerDir: CGFloat = 0.0
    @State private var joystickOffset: CGFloat = 0.0

    // Soft-body pile
    @State private var pile: [PileSlot] = []
    @State private var softBodies: [SoftBodyState] = []

    // Confetti particles
    private struct ConfettiParticle: Identifiable {
        let id: Int
        let dx: CGFloat
        let dy: CGFloat
        let dr: Double
        let color: Color
        let delay: Double
    }

    private let confettiSet: [ConfettiParticle] = [
        ConfettiParticle(id: 0, dx: -44, dy: -54, dr: -150, color: Color(hex: "#34c759"), delay: 0.0),
        ConfettiParticle(id: 1, dx: -30, dy: -66, dr: 120, color: Color(hex: "#ffd60a"), delay: 0.05),
        ConfettiParticle(id: 2, dx: -14, dy: -76, dr: -80, color: Color(hex: "#5cd679"), delay: 0.02),
        ConfettiParticle(id: 3, dx: 2, dy: -80, dr: 60, color: Color(hex: "#5a93c9"), delay: 0.07),
        ConfettiParticle(id: 4, dx: 16, dy: -74, dr: -130, color: Color(hex: "#ffb340"), delay: 0.03),
        ConfettiParticle(id: 5, dx: 30, dy: -64, dr: 100, color: Color(hex: "#a8e6b8"), delay: 0.06),
        ConfettiParticle(id: 6, dx: 44, dy: -52, dr: -110, color: Color(hex: "#34c759"), delay: 0.01),
        ConfettiParticle(id: 7, dx: -54, dy: -36, dr: 90, color: Color(hex: "#e58ab0"), delay: 0.09),
        ConfettiParticle(id: 8, dx: 54, dy: -34, dr: -70, color: Color(hex: "#5a93c9"), delay: 0.08)
    ]

    // Timer loop
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    @State private var lastTick: Date? = nil

    public init(
        targetId: String,
        onVerify: @escaping (String) -> Void,
        onFail: (() -> Void)? = nil
    ) {
        self.targetId = targetId
        self.onVerify = onVerify
        self.onFail = onFail
    }

    private var targetMeta: ToyMeta {
        ToyMeta.meta(for: targetId)
    }

    public var body: some View {
        GeometryReader { geo in
            let scale = min(max(geo.size.width / (GW + 24), 0.75), 1.08)

            VStack(spacing: 12) {
                // Header Status Prompt
                headerView

                // Steps Indicator (1 Steuern, 2 Greifen, 3 Abwerfen)
                stepsIndicator

                // Claw Machine Box (380x320 scaled)
                machineView
                    .frame(width: GW, height: GH)
                    .scaleEffect(scale)
                    .frame(width: GW * scale, height: GH * scale)

                // Console / Joystick & Controls
                consoleView
                    .scaleEffect(scale)
                    .frame(width: GW * scale)

                // Hint footer
                Text("Joystick oder Wischen zum Bewegen · Button zum Greifen & Abwerfen")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.40))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                setupPile()
            }
            .onReceive(timer) { currentTime in
                stepPhysics(now: currentTime)
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isVerified ? Color(hex: "#34c759").opacity(0.20) : Color.white.opacity(0.08))
                        .frame(width: 28, height: 28)

                    Image(systemName: isVerified ? "checkmark.shield.fill" : "shield.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isVerified ? Color(hex: "#34c759") : Color.white.opacity(0.80))
                }

                Text(isVerified ? "Verifiziert" : "Beweise, dass du ein Mensch bist")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }

            if isVerified {
                Text("Du bist ein Mensch. Toller Fang!")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#34c759"))
            } else if let msg = statusMessage {
                Text(msg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#ffd60a"))
            } else {
                HStack(spacing: 6) {
                    Text("Greife mit dem Greifarm:")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.70))

                    HStack(spacing: 4) {
                        toyImage(named: targetId, width: 22)
                        Text(targetMeta.label)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(targetMeta.accentColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Steps Indicator
    private var stepNumber: Int {
        if isVerified || phase == .carry || phase == .toTray || phase == .celebrate { return 3 }
        if phase == .seq { return 2 }
        return 1
    }

    private var stepsIndicator: some View {
        HStack(spacing: 4) {
            stepBadge(num: 1, title: "Steuern", active: stepNumber == 1)
            stepArrow
            stepBadge(num: 2, title: "Greifen", active: stepNumber == 2)
            stepArrow
            stepBadge(num: 3, title: "Abwerfen", active: stepNumber == 3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .clipShape(Capsule())
    }

    private func stepBadge(num: Int, title: String, active: Bool) -> some View {
        HStack(spacing: 5) {
            Text("\(num)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(active ? .black : Color.white.opacity(0.5))
                .frame(width: 16, height: 16)
                .background(active ? Color.white : Color.white.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 11, weight: active ? .bold : .medium))
                .foregroundColor(active ? .white : Color.white.opacity(0.45))
        }
    }

    private var stepArrow: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(Color.white.opacity(0.25))
            .padding(.horizontal, 2)
    }

    // MARK: - Machine Glass Area
    private var machineView: some View {
        ZStack(alignment: .topLeading) {
            // Glass Case Background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#16171b"), Color(hex: "#0e0f13")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                )

            // Rail at top (RAIL_Y = 14)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#444955"), Color(hex: "#23262e")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 6)
                .offset(y: RAIL_Y - 3)

            // Trolley carriage riding rail
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#b4b9c4"), Color(hex: "#666d85")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 28, height: 10)
                .position(x: clawX, y: RAIL_Y)

            // Floor Pile Shadow
            Ellipse()
                .fill(Color.black.opacity(0.55))
                .frame(width: GW - 40, height: 26)
                .position(x: GW / 2, y: GH - 10)

            // Contact Shadow under Claw / Cargo
            let shadowRad = (sway + breeze) * .pi / 180.0
            let shadowLen = max(2.0, clawY - RAIL_Y)
            let shadowEx = clawX + sin(shadowRad) * shadowLen
            let cargoBottom = (carriedIndex >= 0 && carriedIndex < pile.count) ? (carryPos.y + pile[carriedIndex].w / 2) : (clawY + 58)
            let shadowT = max(0.0, min(1.0, 1.0 - (GH - cargoBottom) / 210.0))
            Ellipse()
                .fill(Color.black.opacity(0.12 + 0.38 * shadowT))
                .frame(width: 44 * (1.25 - 0.5 * shadowT), height: 14)
                .position(x: shadowEx, y: GH - 12)

            // Soft-body Pile of Toys
            ForEach(pile) { slot in
                let idx = slot.id
                let bodyState = (idx < softBodies.count) ? softBodies[idx] : SoftBodyState()
                let isCarried = (carriedIndex == idx)

                if !isCarried {
                    toyImage(named: slot.toyId, width: slot.w)
                        .scaleEffect(
                            x: max(0.2, 1.0 - bodyState.sq * 0.6),
                            y: max(0.2, 1.0 + bodyState.sq),
                            anchor: .bottom
                        )
                        .rotationEffect(.degrees(slot.rot + bodyState.rot))
                        .offset(x: bodyState.dx, y: bodyState.dy + bodyState.ey)
                        .position(x: slot.x, y: GH - slot.b - (slot.w / 2) * 0.92)
                        .zIndex(Double(slot.z))
                }
            }

            // Articulated Crane Rig: Cable Coil + Articulated Chrome Claw
            craneRigView
                .zIndex(15)

            // Carried Toy (when gripped)
            if carriedIndex >= 0 && carriedIndex < pile.count && phase != .idle {
                let slot = pile[carriedIndex]
                let sc = max(0.01, 1.0 - swallow * 0.78)
                let sx = sc * (1.0 - stretch * 0.55)
                let sy = sc * (1.0 + stretch)

                toyImage(named: slot.toyId, width: slot.w)
                    .scaleEffect(x: sx, y: sy)
                    .rotationEffect(.degrees(sway + breeze + carriedRot))
                    .opacity(swallow > 0 ? max(0.0, 1.0 - swallow) : 1.0)
                    .position(x: carryPos.x, y: carryPos.y)
                    .zIndex(20)
            }

            // Glass Shine reflection
            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.0), Color.white.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { val in
                    guard phase == .idle || phase == .carry else { return }
                    let touchX = val.location.x
                    let diff = touchX - clawX
                    steerDir = max(-1.0, min(1.0, diff / 40.0))
                }
                .onEnded { _ in
                    steerDir = 0.0
                }
        )
    }

    // MARK: - Articulated Crane Rig
    private var craneRigView: some View {
        let cableLen = max(2.0, clawY - RAIL_Y)

        return ZStack(alignment: .top) {
            // Cable Coil Spring (stretches with cableLen)
            CoilSpringShape()
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#9a9fa8"), Color(hex: "#666d85")],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 14, height: cableLen)
                .position(x: 18, y: cableLen / 2)

            // Chrome Claw Assembly at end of cable
            ZStack {
                // Left Arm (rotates +15 * clawClose around pivot 20.6, 22.7)
                ZStack {
                    ForEach(0..<ClawVectorData.armLPaths.count, id: \.self) { idx in
                        let item = ClawVectorData.armLPaths[idx]
                        item.1.fill(item.0)
                    }
                }
                .rotationEffect(.degrees(15.0 * clawClose), anchor: UnitPoint(x: ClawVectorData.pivot.x / 40.0, y: ClawVectorData.pivot.y / 40.0))

                // Right Arm (rotates -15 * clawClose around pivot 20.6, 22.7)
                ZStack {
                    ForEach(0..<ClawVectorData.armRPaths.count, id: \.self) { idx in
                        let item = ClawVectorData.armRPaths[idx]
                        item.1.fill(item.0)
                    }
                }
                .rotationEffect(.degrees(-15.0 * clawClose), anchor: UnitPoint(x: ClawVectorData.pivot.x / 40.0, y: ClawVectorData.pivot.y / 40.0))

                // Central Chrome Body
                ZStack {
                    ForEach(0..<ClawVectorData.bodyPaths.count, id: \.self) { idx in
                        let item = ClawVectorData.bodyPaths[idx]
                        item.1.fill(item.0)
                    }
                }
            }
            .frame(width: 40, height: 40)
            .scaleEffect(2.2)
            .position(x: 18, y: cableLen + 22)
        }
        .frame(width: 36, height: cableLen + 70)
        .rotationEffect(.degrees(sway + breeze), anchor: .top)
        .position(x: clawX, y: RAIL_Y + (cableLen + 70) / 2)
    }

    // MARK: - Console: Joystick, Collection Chute & Action Button
    private var consoleView: some View {
        HStack(spacing: 16) {
            // Tactile Arcade Joystick
            joystickView

            // Collection Tray / Chute with Hatch Doors
            trayChuteView

            // Arcade Action Button (Greifen / Abwerfen)
            actionButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var joystickView: some View {
        ZStack {
            // Socket Base
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#2a2d36"), Color(hex: "#111216")],
                        center: .center,
                        startRadius: 2,
                        endRadius: 36
                    )
                )
                .frame(width: 68, height: 68)
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

            // Inner Ring
            Circle()
                .fill(Color(hex: "#181a20"))
                .frame(width: 44, height: 44)

            // Joystick Shaft & Ball Head
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#d0d4dc"), Color(hex: "#707684")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 7, height: 26)
                    .offset(y: -8)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#ff4d4d"), Color(hex: "#990000")],
                            center: UnitPoint(x: 0.35, y: 0.35),
                            startRadius: 1,
                            endRadius: 16
                        )
                    )
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.6), radius: 3, y: 2)
                    .offset(y: -22)
            }
            .rotationEffect(.degrees(Double(joystickOffset * 1.15)), anchor: .center)
            .offset(x: joystickOffset * 0.7)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { val in
                    guard phase == .idle || phase == .carry else { return }
                    let dx = max(-26.0, min(26.0, val.translation.width))
                    joystickOffset = dx
                    steerDir = dx / 26.0
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        joystickOffset = 0.0
                    }
                    steerDir = 0.0
                }
        )
    }

    private var trayChuteView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#14151a"))
                .frame(height: 68)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            trayMode == .win ? Color(hex: "#34c759") :
                            trayMode == .no ? Color(hex: "#ff9500") :
                            overTray ? Color.white : Color.white.opacity(0.15),
                            lineWidth: overTray || trayMode == .win ? 2 : 1
                        )
                )

            // Hatch Interior & Sliding Doors
            ZStack {
                // Dark Mouth
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .frame(width: 80, height: 24)

                // Left & Right Hatch Doors
                let doorOffset: CGFloat = (trayMode == .open) ? 36.0 : 0.0
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(hex: "#282a32"))
                        .frame(width: 40, height: 24)
                        .offset(x: -doorOffset)

                    Rectangle()
                        .fill(Color(hex: "#282a32"))
                        .frame(width: 40, height: 24)
                        .offset(x: doorOffset)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .animation(.easeOut(duration: 0.22), value: trayMode)
            }
            .offset(y: -14)

            // Label & Icons
            HStack(spacing: 6) {
                if trayMode == .win {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#34c759"))
                    Text("Toller Fang!")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#34c759"))
                } else if trayMode == .no {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundColor(Color(hex: "#ff9500"))
                    Text("Falsches Spielzeug")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#ff9500"))
                } else if overTray {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.white)
                    Text("Loslassen!")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .foregroundColor(Color.white.opacity(0.40))
                    Text("Hier abwerfen")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.50))
                }
            }
            .offset(y: 14)

            // Confetti Burst on Win
            if trayMode == .win {
                ForEach(confettiSet) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: 7, height: 7)
                        .offset(x: p.dx, y: p.dy)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    private var actionButton: some View {
        Button(action: performAction) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: overTray ? [Color(hex: "#34c759"), Color(hex: "#1e7e34")] : [Color(hex: "#ff3b30"), Color(hex: "#a3160e")],
                            center: UnitPoint(x: 0.35, y: 0.35),
                            startRadius: 2,
                            endRadius: 36
                        )
                    )
                    .frame(width: 68, height: 68)
                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5))
                    .shadow(color: (overTray ? Color(hex: "#34c759") : Color.red).opacity(0.4), radius: 8, y: 3)

                Text(phase == .carry ? "Abwerfen" : "Greifen")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isVerified || (phase != .idle && phase != .carry))
    }

    // MARK: - Action Button Handler
    private func performAction() {
        guard !isVerified else { return }

        if phase == .idle {
            triggerHaptic(style: .medium)
            statusMessage = nil
            clawClose = 0.0
            stage = .antic
            stageTime = 0.0
            phase = .seq
        } else if phase == .carry {
            if clawX >= TRAY_MIN && clawX <= TRAY_MAX {
                triggerHaptic(style: .medium)
                stage = .open
                stageTime = 0.0
                fallV = 0.0
                swallow = 0.0
                stretch = 0.0
                isReleased = false
                overTray = false
                phase = .toTray
            } else {
                statusMessage = "Bewege die Beute zuerst über die Abwurfzone."
                triggerHaptic(style: .light)
            }
        }
    }

    // MARK: - Physics Integration (60 Hz)
    private func stepPhysics(now: Date) {
        guard let prev = lastTick else {
            lastTick = now
            return
        }
        let dtRaw = min(0.04, max(0.004, now.timeIntervalSince(prev)))
        lastTick = now
        let dt = dtRaw
        let f = dt * 60.0

        // Pendulum lean opposite motion
        let lean = (phase == .idle || phase == .carry) ? -vx * 0.042 : 0.0
        swayV += (lean - sway) * 0.05 * f
        swayV *= pow(0.93, f)
        sway += swayV * f

        // Ambient sine breeze so crane never freezes solid
        let tSec = now.timeIntervalSinceReferenceDate
        breeze = sin(tSec / 1.5) * 0.45 + sin(tSec / 0.521) * 0.12

        // Soft-bodies simulation
        for i in 0..<softBodies.count {
            guard i < pile.count else { continue }
            var b = softBodies[i]

            if !b.landed {
                if b.delay > 0 {
                    b.delay -= dt
                } else {
                    b.evy += ENTRANCE_G * dt
                    b.ey += b.evy * dt
                    if b.ey >= 0 {
                        b.ey = 0
                        b.landed = true
                        b.vsq += min(0.055, b.evy * 0.00006)
                        b.vrot += Double.random(in: -0.8...0.8)
                        ripple(at: pile[i].x, power: min(0.22, b.evy * 0.0002), except: i)
                    }
                }
            }

            b.vdx += -b.dx * 0.055 * f
            b.vdy += -b.dy * 0.055 * f
            b.vrot += -b.rot * 0.05 * f
            b.vsq += -b.sq * 0.13 * f

            let damp = pow(0.90, f)
            b.vdx *= damp
            b.vdy *= damp
            b.vrot *= pow(0.91, f)
            b.vsq *= pow(0.84, f)

            b.dx += b.vdx * f
            b.dy += b.vdy * f
            b.rot += b.vrot * f
            b.sq += b.vsq * f

            softBodies[i] = b
        }

        // Trolley movement during idle / carry
        if phase == .idle || phase == .carry {
            drive += (steerDir - drive) * (1.0 - exp(-13.0 * dt))
            vx += drive * 720.0 * dt
            vx *= exp(-5.5 * dt)
            clawX = min(CLAW_MAX, max(CLAW_MIN, clawX + vx * dt))

            if phase == .carry {
                carriedRot += (sway * 0.5 - carriedRot) * (1.0 - exp(-6.0 * dt))
                let pendPoint = pendulumEnd()
                carryPos = CGPoint(x: pendPoint.x, y: gripY(ey: pendPoint.y))

                let isOver = (clawX >= TRAY_MIN && clawX <= TRAY_MAX)
                if isOver != overTray {
                    overTray = isOver
                    trayMode = isOver ? .hot : .normal
                }
            }
        } else if phase == .seq {
            stepGrabSequence(dt: dt)
        } else if phase == .toTray {
            stepDropSequence(dt: dt)
        } else if phase == .celebrate {
            stageTime += dt
            if stage == .beat && stageTime >= 0.28 {
                stage = .shine
                isVerified = true
                triggerHapticNotification(type: .success)
                onVerify(targetId)
            } else if stage == .shine && stageTime >= 0.98 {
                phase = .done
            }
        } else if phase == .deny {
            stageTime += dt
            let p = min(1.0, stageTime / 0.46)
            swallow = easeOutCubic(p)
            carryPos.y -= 46.0 * dt

            if p >= 1.0 {
                trayMode = .normal
                let idx = carriedIndex
                swallow = 0.0
                carriedIndex = -1
                if idx >= 0 && idx < softBodies.count {
                    softBodies[idx].vsq += 0.05
                    softBodies[idx].vrot += Double.random(in: -1.0...1.0)
                    ripple(at: pile[idx].x, power: 0.25, except: idx)
                }
                phase = .idle
            }
        }
    }

    // MARK: - 7-Stage Grab Sequence
    private func stepGrabSequence(dt: CGFloat) {
        stageTime += dt

        switch stage {
        case .antic:
            let p = min(1.0, stageTime / 0.16)
            clawY = HOME_Y - 8.0 * easeOutCubic(p)
            clawClose = -0.55 * easeOutCubic(p)

            if p >= 1.0 {
                let cand = candidateAt(x: clawX)
                if cand >= 0 {
                    let cy = GH - pile[cand].b - (pile[cand].w / 2) * 0.92
                    depthY = min(GH - 46, max(HOME_Y + 50, cy - GRIP_OFFSET - pile[cand].w / 2))
                } else {
                    depthY = DROP_Y
                }
                stage = .down
                stageTime = 0.0
            }

        case .down:
            let p = min(1.0, stageTime / 0.78)
            clawY = (HOME_Y - 8.0) + (depthY - HOME_Y + 8.0) * easeInQuad(p)

            if clawY > 130 {
                for i in 0..<pile.count {
                    let d = abs(pile[i].x - clawX)
                    if d < 56 {
                        let push = (1.0 - d / 56.0) * 7.0 * dt
                        let side: CGFloat = pile[i].x < clawX ? -1 : 1
                        softBodies[i].vdx += side * push
                        softBodies[i].vsq += push * 0.012
                    }
                }
            }

            if p >= 1.0 {
                stage = .dwell1
                stageTime = 0.0
            }

        case .dwell1:
            let p = min(1.0, stageTime / 0.18)
            clawY = depthY + 3.5 * sin(.pi * p)
            if p >= 1.0 {
                clawY = depthY
                stage = .close
                stageTime = 0.0
            }

        case .close:
            let p = min(1.0, stageTime / 0.45)
            clawClose = -0.55 + 1.55 * easeOutCubic(p)

            if p >= 1.0 {
                let best = candidateAt(x: clawX)
                carriedIndex = best
                if best >= 0 {
                    let pSlot = pile[best]
                    let cy = GH - pSlot.b - (pSlot.w / 2) * 0.92
                    carryPos = CGPoint(x: pSlot.x, y: cy)
                    carriedRot = pSlot.rot + softBodies[best].rot
                    ripple(at: pSlot.x, power: 0.35, except: best)
                    triggerHaptic(style: .medium)
                } else {
                    ripple(at: clawX, power: 0.20, except: -1)
                }
                stage = .dwell2
                stageTime = 0.0
            }

        case .dwell2:
            let p = min(1.0, stageTime / 0.26)
            if carriedIndex >= 0 {
                carriedRot += -carriedRot * (1.0 - exp(-3.5 * dt))
                let pendPoint = pendulumEnd()
                carryPos = CGPoint(x: pendPoint.x, y: gripY(ey: pendPoint.y))
            }
            if p >= 1.0 {
                stage = (carriedIndex >= 0) ? .load : .up
                stageTime = 0.0
            }

        case .load:
            let p = min(1.0, stageTime / 0.24)
            let bell = sin(.pi * p)
            clawY = depthY + 6.0 * bell
            clawClose = 1.0 + 0.12 * bell

            if carriedIndex >= 0 {
                carriedRot += -carriedRot * (1.0 - exp(-3.5 * dt))
                let pendPoint = pendulumEnd()
                carryPos = CGPoint(x: pendPoint.x, y: gripY(ey: pendPoint.y))
            }
            if p >= 1.0 {
                clawY = depthY
                stage = .up
                stageTime = 0.0
            }

        case .up:
            let p = min(1.0, stageTime / 0.95)
            clawY = depthY + (HOME_Y - depthY) * easeInOutCubic(p)

            if carriedIndex >= 0 {
                carriedRot += -carriedRot * (1.0 - exp(-3.5 * dt))
                let pendPoint = pendulumEnd()
                carryPos = CGPoint(x: pendPoint.x, y: gripY(ey: pendPoint.y))
            }

            if p >= 1.0 {
                if carriedIndex >= 0 {
                    phase = .carry
                    statusMessage = nil
                } else {
                    phase = .idle
                    statusMessage = "Kein Spielzeug gegriffen. Versuche es erneut."
                }
            }

        default:
            break
        }
    }

    // MARK: - Drop Sequence (Right or Wrong Toy)
    private func stepDropSequence(dt: CGFloat) {
        guard carriedIndex >= 0 && carriedIndex < pile.count else {
            phase = .idle
            return
        }
        let isTarget = (pile[carriedIndex].toyId == targetId)

        if stage == .open {
            stageTime += dt
            let p = min(1.0, stageTime / 0.40)
            clawClose = 1.0 - easeOutCubic(p)

            if stageTime > 0.12 && !isReleased {
                isReleased = true
                if isTarget {
                    trayMode = .open
                    fallV = 30.0
                } else {
                    fallV = 40.0
                }
            }
        }

        if isTarget && isReleased && carriedIndex >= 0 {
            fallV = min(fallV + DROP_G * dt, 460.0)
            carryPos.y += fallV * dt
            carryPos.x += (TRAY_CX - carryPos.x) * (1.0 - exp(-2.2 * dt))
            carriedRot += -carriedRot * (1.0 - exp(-4.0 * dt))
            stretch = (abs(fallV) / 460.0) * 0.09

            let toyW = pile[carriedIndex].w
            let sunk = carryPos.y + toyW / 2 - MOUTH_Y

            if sunk >= toyW + 4.0 {
                carriedIndex = -1
                overTray = false
                trayMode = .win
                stage = .beat
                stageTime = 0.0
                phase = .celebrate
            }
        }

        if !isTarget && fallV != 0.0 {
            fallV = min(fallV + DROP_G * dt, 360.0)
            carryPos.y += fallV * dt
            carryPos.x += (TRAY_CX - carryPos.x) * (1.0 - exp(-4.0 * dt))
            carriedRot += -carriedRot * (1.0 - exp(-3.0 * dt))
            stretch = (abs(fallV) / 460.0) * 0.09

            if fallV > 0 && carryPos.y >= TRAY_CY {
                if fallV > 200.0 {
                    carryPos.y = TRAY_CY
                    fallV = -fallV * 0.28
                    carriedRot += Double.random(in: -7.0...7.0)
                } else {
                    carryPos.y = TRAY_CY
                    fallV = 0.0
                    stretch = 0.0
                    overTray = false
                    trayMode = .no

                    let caughtMeta = ToyMeta.meta(for: pile[carriedIndex].toyId)
                    statusMessage = "Das war \(caughtMeta.label)! Finde: \(targetMeta.label)."
                    triggerHapticNotification(type: .warning)
                    onFail?()

                    stage = .beat
                    stageTime = 0.0
                    phase = .deny
                }
            }
        }
    }

    // MARK: - Mathematical Helpers
    private func pendulumEnd() -> CGPoint {
        let len = max(2.0, clawY - RAIL_Y)
        let rad = (sway + breeze) * .pi / 180.0
        return CGPoint(x: clawX + sin(rad) * len, y: RAIL_Y + cos(rad) * len)
    }

    private func gripY(ey: CGFloat) -> CGFloat {
        let w = (carriedIndex >= 0 && carriedIndex < pile.count) ? pile[carriedIndex].w : 80.0
        return ey + GRIP_OFFSET + w / 2.0
    }

    private func candidateAt(x: CGFloat) -> Int {
        var best = -1
        var bestScore: CGFloat = -100000.0
        for i in 0..<pile.count {
            let d = abs(pile[i].x - x)
            if d < GRAB_RADIUS {
                let score = CGFloat(pile[i].z) * 100.0 - d
                if score > bestScore {
                    bestScore = score
                    best = i
                }
            }
        }
        return best
    }

    private func ripple(at x: CGFloat, power: CGFloat, except: Int) {
        for i in 0..<pile.count {
            if i == except || i == carriedIndex { continue }
            let d = abs(pile[i].x - x)
            if d < 80.0 {
                let f = (1.0 - d / 80.0) * power
                let side: CGFloat = pile[i].x < x ? -1 : 1
                softBodies[i].vdx += side * f * 1.6
                softBodies[i].vdy -= f * 1.1
                softBodies[i].vrot += Double(side * f * 2.0)
                softBodies[i].vsq += f * 0.02
            }
        }
    }

    private func easeInQuad(_ p: CGFloat) -> CGFloat { p * p }
    private func easeOutCubic(_ p: CGFloat) -> CGFloat { 1.0 - pow(1.0 - p, 3) }
    private func easeInOutCubic(_ p: CGFloat) -> CGFloat {
        p < 0.5 ? 4.0 * p * p * p : 1.0 - pow(-2.0 * p + 2.0, 3) / 2.0
    }

    // MARK: - Pile Generation
    private func setupPile() {
        let target = targetId
        var allToys = ToyMeta.all.shuffled()
        if let idx = allToys.firstIndex(where: { $0.id == target }) {
            let tgt = allToys.remove(at: idx)
            allToys.insert(tgt, at: 0)
        }
        let tgt = allToys[0]
        let rest = Array(allToys.dropFirst())

        let nB = 8
        let bottomIdx = Int.random(in: 2...5)
        var slots: [PileSlot] = []

        var r = 0
        var frontW: [CGFloat] = []
        var frontToys: [ToyMeta] = []
        for i in 0..<nB {
            let isTarget = (i == bottomIdx)
            let t = isTarget ? tgt : rest[r]
            if !isTarget { r += 1 }
            frontToys.append(t)
            let widthScale = isTarget ? CGFloat.random(in: 1.0...1.05) : CGFloat.random(in: 0.76...0.86)
            frontW.append(t.baseWidth * widthScale)
        }

        var xs: [CGFloat] = [0]
        for i in 1..<nB {
            let dist = ((frontW[i - 1] + frontW[i]) / 2.0) * CGFloat.random(in: 0.62...0.68)
            xs.append(xs[i - 1] + dist)
        }

        let span = xs[nB - 1]
        let fit = min(1.0, (GW - 80.0) / span)
        for i in 0..<nB { frontW[i] *= fit }
        let offset = (GW - span * fit) / 2.0

        var centers: [CGFloat] = []
        for i in 0..<nB {
            let cx = offset + xs[i] * fit + CGFloat.random(in: -3.0...3.0)
            centers.append(cx)
            let isTarget = (i == bottomIdx)
            slots.append(
                PileSlot(
                    id: i,
                    toyId: frontToys[i].id,
                    w: frontW[i],
                    x: min(GW - 26, max(26, cx)),
                    b: CGFloat.random(in: 0.0...2.0),
                    z: isTarget ? 4 : 2,
                    rot: Double.random(in: -7.0...7.0),
                    dropFrom: -CGFloat.random(in: 340.0...440.0),
                    delay: Double(i) * 0.05 + Double.random(in: 0.0...0.1)
                )
            )
        }

        var gaps: [Int] = []
        for g in 0..<(nB - 1) {
            if g == bottomIdx - 1 || g == bottomIdx { continue }
            gaps.append(g)
        }
        let useGaps = Array(gaps.shuffled().prefix(4))
        for (ti, g) in useGaps.enumerated() {
            guard r < rest.count else { break }
            let t = rest[r]
            r += 1
            let cx = (centers[g] + centers[g + 1]) / 2.0 + CGFloat.random(in: -3.0...3.0)
            slots.append(
                PileSlot(
                    id: nB + ti,
                    toyId: t.id,
                    w: t.baseWidth * CGFloat.random(in: 0.70...0.80),
                    x: min(GW - 26, max(26, cx)),
                    b: CGFloat.random(in: 6.0...16.0),
                    z: 1,
                    rot: Double.random(in: -8.0...8.0),
                    dropFrom: -CGFloat.random(in: 360.0...470.0),
                    delay: 0.45 + Double(ti) * 0.08 + Double.random(in: 0.0...0.1)
                )
            )
        }

        pile = slots
        softBodies = slots.map { s in
            SoftBodyState(
                dx: 0,
                dy: 0,
                rot: 0,
                sq: 0,
                vdx: 0,
                vdy: 0,
                vrot: 0,
                vsq: 0,
                ey: s.dropFrom,
                evy: 0,
                delay: s.delay,
                landed: false
            )
        }
    }

    // MARK: - Toy Image Loader
    private func toyImage(named name: String, width: CGFloat) -> some View {
        Group {
            if let img = loadToyImage(named: name) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: width)
            } else {
                let meta = ToyMeta.meta(for: name)
                ZStack {
                    Circle()
                        .fill(meta.accentColor.opacity(0.85))
                        .frame(width: width, height: width)
                    Text(String(meta.label.prefix(1)))
                        .font(.system(size: width * 0.45, weight: .bold))
                        .foregroundColor(.black)
                }
            }
        }
    }

    private func loadToyImage(named name: String) -> UIImage? {
        if let img = UIImage(named: name) { return img }
        if let path = Bundle.main.path(forResource: name, ofType: "png"),
           let img = UIImage(contentsOfFile: path) { return img }
        if let path = Bundle.main.path(forResource: name, ofType: "png", inDirectory: "Toys"),
           let img = UIImage(contentsOfFile: path) { return img }
        if let path = Bundle.main.path(forResource: name, ofType: "png", inDirectory: "Resources/Toys"),
           let img = UIImage(contentsOfFile: path) { return img }
        if let urls = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: nil) {
            for url in urls where url.deletingPathExtension().lastPathComponent == name {
                if let img = UIImage(contentsOfFile: url.path) { return img }
            }
        }
        return nil
    }

    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    private func triggerHapticNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

// MARK: - Button Press Style
private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
