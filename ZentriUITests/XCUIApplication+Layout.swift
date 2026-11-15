import XCTest

extension XCUIApplication {
    /// The root tab titled `title`, wherever the system draws the tabs.
    ///
    /// iPhone and iPad put them in a tab bar. iPhone Duo's outer display moves them into a vertical
    /// bar beside the content, whose buttons are not inside a tab bar element, so a query through
    /// `tabBars` finds nothing there although every tab is on screen. No content button in Zentri
    /// shares a tab's title, so the plain button query is unambiguous.
    func tab(_ title: String) -> XCUIElement {
        tabBars.firstMatch.exists ? tabBars.buttons[title] : buttons[title].firstMatch
    }
}

extension XCUIApplication {
    /// Scrolls down the content until the element exists and can be tapped, and returns it.
    ///
    /// Lists and forms only create the rows near the screen, so on a short display — iPhone Duo's
    /// outer one is 678 points tall — a row further down does not exist until it is scrolled to.
    @discardableResult
    func scrolledTo(_ element: XCUIElement, maxSwipes: Int = 8) -> XCUIElement {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            scrollContentUp()
            swipes += 1
        }
        return element
    }

    /// Drags the content up from the upper part of the screen. A plain `swipeUp()` starts at the
    /// centre, which on a short display with the keyboard up lands on the keyboard and scrolls
    /// nothing.
    private func scrollContentUp() {
        let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        let end = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// Drags the content down within the upper part of the screen, clear of a raised keyboard.
    private func scrollContentDown() {
        let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
        let end = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// Scrolls back up until the element exists and can be tapped, and returns it.
    ///
    /// On iPhone Duo's outer display a navigation bar hides its buttons once the content beneath it
    /// scrolls, and shows them again at the top, so an Edit or Done button may need the content
    /// scrolled back first.
    @discardableResult
    func scrolledBackTo(_ element: XCUIElement, maxSwipes: Int = 8) -> XCUIElement {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            scrollContentDown()
            swipes += 1
        }
        return element
    }

    /// Taps the navigation back button. On iPhone Duo's outer display it sits in the vertical bar,
    /// outside the navigation bar element, where it keeps the system's `BackButton` identifier.
    func goBack() {
        let back = buttons["BackButton"].firstMatch
        let barButton = navigationBars.buttons.element(boundBy: 0)
        if back.exists {
            back.tap()
        } else if barButton.exists {
            barButton.tap()
        } else {
            // Scrolled content has hidden the bar's buttons; scrolling back shows them again.
            scrolledBackTo(back).tap()
        }
    }

    /// The top of onboarding's pinned footer: Back sits above Continue when the buttons stack.
    var onboardingFooterTop: CGFloat {
        let tops = [buttons["onboarding.continue"], buttons["onboarding.back"]]
            .filter(\.exists)
            .map(\.frame.minY)
        return tops.min() ?? frame.maxY
    }
}
