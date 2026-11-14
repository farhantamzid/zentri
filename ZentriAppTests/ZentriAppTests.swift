import Testing
import ZentriCore

/// Scaffold check that the app's unit-test bundle links the shared core package.
@Test func appUnitTestTargetLinksZentriCore() {
    #expect(AppGroup.identifier == "group.com.farhantamzid.zentri")
}
