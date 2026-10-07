import Foundation

public struct AppSettings: Codable, Equatable {
    public var requireTouchID: Bool
    public var autoHideAfterCopy: Bool
    public var showNextCodePreview: Bool
    public var sortAlphabetically: Bool

    public init(
        requireTouchID: Bool = false,
        autoHideAfterCopy: Bool = false,
        showNextCodePreview: Bool = true,
        sortAlphabetically: Bool = false
    ) {
        self.requireTouchID = requireTouchID
        self.autoHideAfterCopy = autoHideAfterCopy
        self.showNextCodePreview = showNextCodePreview
        self.sortAlphabetically = sortAlphabetically
    }
}
