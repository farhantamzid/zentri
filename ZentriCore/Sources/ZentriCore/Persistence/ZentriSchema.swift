import SwiftData

/// The first shipped version of the app's SwiftData schema.
public enum ZentriSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            Account.self,
            Transaction.self,
            BalanceCheckpoint.self,
            RawMessage.self,
            ParsingRule.self,
            Category.self,
            CategorizationRule.self,
        ]
    }
}

/// The migration plan for the app's store; v1 has no stages yet.
public enum ZentriMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [ZentriSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
