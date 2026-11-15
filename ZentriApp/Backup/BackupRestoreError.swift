/// Why a restore did not finish completely.
enum BackupRestoreError: Error, Equatable {
    /// A replace restored the data, but the backup's settings could not be saved, so the currency
    /// and display settings are still the ones from before. Restoring again retries.
    case settingsNotSaved
}
