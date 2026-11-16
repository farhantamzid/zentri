import UIKit
import XCTest

/// Settings › Appearance › Theme: picking Light or Dark redraws the app in that mode, whatever the
/// simulator's own appearance, and System hands it back to the device.
///
/// The check reads the pixels: the screenshot's average brightness, which the canvas behind every
/// screen dominates, is far higher in Light than in Dark.
@MainActor
final class AppearanceModeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testPickingDarkOrLightRedrawsTheApp() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestSkipOnboarding", "-UITestSeed"]
        app.launch()
        let settings = app.tab("Settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "The tab bar did not appear")
        settings.tap()
        app.buttons["settings.appearance"].tap()

        let picker = app.segmentedControls["appearance.mode"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Appearance has no Theme picker")
        XCTAssertTrue(picker.buttons["System"].isSelected, "A fresh install does not follow the device")

        picker.buttons["Light"].tap()
        XCTAssertTrue(waitForBrightness(of: app, where: { $0 > 0.6 }), "Light did not draw the app light")
        let light = brightness(of: app)

        picker.buttons["Dark"].tap()
        XCTAssertTrue(picker.buttons["Dark"].isSelected, "Dark is not selected after picking it")
        XCTAssertTrue(waitForBrightness(of: app, where: { $0 < 0.35 }), "Dark did not draw the app dark")
        let dark = brightness(of: app)
        XCTAssertLessThan(dark, light - 0.3, "Dark (\(dark)) is not clearly darker than Light (\(light))")

        // The choice is app-wide: another tab draws dark too.
        app.tab("Overview").tap()
        XCTAssertTrue(waitForBrightness(of: app, where: { $0 < 0.35 }), "The Overview tab is not dark")
    }

    /// Waits up to five seconds for the screen's brightness to satisfy `condition`, since the mode
    /// change redraws on the next frame.
    private func waitForBrightness(of app: XCUIApplication, where condition: (Double) -> Bool) -> Bool {
        let deadline = Date.now.addingTimeInterval(5)
        repeat {
            if condition(brightness(of: app)) { return true }
            RunLoop.current.run(until: .now.addingTimeInterval(0.25))
        } while Date.now < deadline
        return false
    }

    /// The screenshot's mean relative luminance, from 0 (black) to 1 (white).
    private func brightness(of app: XCUIApplication) -> Double {
        guard let image = app.screenshot().image.cgImage else { return .nan }
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return .nan }
        var total = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = Double(pixels[index]), green = Double(pixels[index + 1]), blue = Double(pixels[index + 2])
            total += (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255
        }
        return total / Double(side * side)
    }
}
