import UniformTypeIdentifiers

extension UTType {
    /// A Zentri backup file, `.zentri.json`, declared as an exported type in the app's Info.plist.
    static let zentriBackup = UTType(exportedAs: "com.farhantamzid.zentri.backup", conformingTo: .json)
}
