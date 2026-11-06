import Foundation

/// TegakiKit/HolidayData, found from this file's own place (Tests/HolidaysTests/../../HolidayData;
/// docs/M7B_CONTRACT.md D8, §0): the tests read the repository's data. The app reads its bundle's
/// copy and has no such function, so no path of the machine that built it goes into the app.
func holidayDataDirectory() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // Tests/HolidaysTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // TegakiKit
        .appendingPathComponent("HolidayData", isDirectory: true)
}
