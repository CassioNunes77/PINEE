import Foundation

public struct DateRange {
    public var start: Date
    public var end: Date
    public var displayText: String
    
    public init(start: Date, end: Date, displayText: String) {
        self.start = start
        self.end = end
        self.displayText = displayText
    }
}
