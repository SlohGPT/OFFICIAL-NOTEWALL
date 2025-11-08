import Foundation
import SwiftUI
import UIKit

struct Note: Identifiable, Codable {
    let id: UUID
    var text: String
    var isCompleted: Bool

    init(id: UUID = UUID(), text: String, isCompleted: Bool = false) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
    }
}

extension Notification.Name {
    static let requestWallpaperUpdate = Notification.Name("requestWallpaperUpdate")
    static let wallpaperGenerationFinished = Notification.Name("wallpaperGenerationFinished")
}

enum LockScreenBackgroundOption: String, CaseIterable, Identifiable {
    case black
    case gray

    static let `default` = LockScreenBackgroundOption.black

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .black: return "Black"
        case .gray: return "Gray"
        }
    }

    var color: Color {
        switch self {
        case .black:
            return Color(red: 2 / 255, green: 2 / 255, blue: 2 / 255)
        case .gray:
            return Color(red: 40 / 255, green: 40 / 255, blue: 40 / 255)
        }
    }

    var uiColor: UIColor {
        switch self {
        case .black:
            return UIColor(red: 2 / 255, green: 2 / 255, blue: 2 / 255, alpha: 1)
        case .gray:
            return UIColor(red: 40 / 255, green: 40 / 255, blue: 40 / 255, alpha: 1)
        }
    }
}

enum LockScreenBackgroundMode: String, Identifiable {
    case presetBlack
    case presetGray
    case photo

    static let `default` = LockScreenBackgroundMode.presetBlack

    var id: String { rawValue }

    var presetOption: LockScreenBackgroundOption? {
        switch self {
        case .presetBlack: return .black
        case .presetGray: return .gray
        case .photo: return nil
        }
    }

    static func preset(for option: LockScreenBackgroundOption) -> LockScreenBackgroundMode {
        switch option {
        case .black: return .presetBlack
        case .gray: return .presetGray
        }
    }
}

enum PresetOption: String, CaseIterable, Identifiable {
    case black
    case gray

    var id: String { rawValue }

    var title: String {
        switch self {
        case .black: return "Black"
        case .gray: return "Gray"
        }
    }

    var previewColor: Color {
        lockScreenOption.color
    }

    var textColor: Color {
        .white
    }

    var lockScreenOption: LockScreenBackgroundOption {
        switch self {
        case .black: return .black
        case .gray: return .gray
        }
    }

    var uiColor: UIColor {
        lockScreenOption.uiColor
    }
}
