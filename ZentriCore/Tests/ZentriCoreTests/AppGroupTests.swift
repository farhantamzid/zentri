import Testing
@testable import ZentriCore

@Test func appGroupConstantsAreStable() {
    #expect(AppGroup.identifier == "group.com.farhantamzid.zentri")
    #expect(AppGroup.widgetSnapshotFileName == "widget-snapshot.json")
    #expect(AppGroup.settingsFileName == "settings.json")
}
