import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// The only file touching the sqlite3 C API; everything else uses RunRecord values.
actor RunStore {
    static let shared = RunStore()

    private var db: OpaquePointer?
    private var openAttempted = false

    // A telemetry failure must never fail the user's command
    func record(_ run: RunRecord) {
        guard let db = connection() else { return }

        let sql = """
        INSERT INTO runs (cwd, alias_name, command_template, execution_type, exit_code, duration_ms, started_at,
                          machine_id, hw_model, cpu_brand, perf_cores, efficiency_cores, memory_bytes, os_version, runs_since_boot)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            reportError("prepare insert", db)
            return
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, run.cwd, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, run.aliasName, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, run.commandTemplate, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, run.executionType.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 5, Int64(run.exitCode))
        sqlite3_bind_int64(statement, 6, Int64(run.durationMs))
        sqlite3_bind_int64(statement, 7, Int64(run.startedAt.timeIntervalSince1970))
        if let context = run.context {
            sqlite3_bind_text(statement, 8, context.machineID, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 9, context.machine.model, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 10, context.machine.cpuBrand, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(statement, 11, Int64(context.machine.performanceCores))
            sqlite3_bind_int64(statement, 12, Int64(context.machine.efficiencyCores))
            sqlite3_bind_int64(statement, 13, context.machine.memoryBytes)
            sqlite3_bind_text(statement, 14, context.machine.osVersion, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(statement, 15, Int64(context.runsSinceBoot))
        }
        // Parameters left unbound insert as NULL, which is what a missing context means

        if sqlite3_step(statement) != SQLITE_DONE {
            reportError("insert run", db)
        }
    }

    func recent(cwd: String, alias: String, limit: Int) -> [RunRecord] {
        guard let db = connection() else { return [] }

        let sql = """
        SELECT cwd, alias_name, command_template, execution_type, exit_code, duration_ms, started_at,
               machine_id, hw_model, cpu_brand, perf_cores, efficiency_cores, memory_bytes, os_version, runs_since_boot
        FROM runs WHERE cwd = ? AND alias_name = ?
        ORDER BY id DESC LIMIT ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            reportError("prepare select", db)
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, cwd, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, alias, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 3, Int64(limit))

        var runs: [RunRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            // Rows written before schema v2 have no machine context
            var context: RunContext?
            if sqlite3_column_type(statement, 7) != SQLITE_NULL {
                context = RunContext(
                    machineID: text(statement, 7),
                    machine: MachineInfo(
                        model: text(statement, 8),
                        cpuBrand: text(statement, 9),
                        performanceCores: Int(sqlite3_column_int64(statement, 10)),
                        efficiencyCores: Int(sqlite3_column_int64(statement, 11)),
                        memoryBytes: sqlite3_column_int64(statement, 12),
                        osVersion: text(statement, 13)
                    ),
                    runsSinceBoot: Int(sqlite3_column_int64(statement, 14))
                )
            }
            runs.append(RunRecord(
                cwd: text(statement, 0),
                aliasName: text(statement, 1),
                commandTemplate: text(statement, 2),
                executionType: ExecutionType(rawValue: text(statement, 3)) ?? .sequential,
                exitCode: Int32(sqlite3_column_int64(statement, 4)),
                durationMs: Int(sqlite3_column_int64(statement, 5)),
                startedAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 6))),
                context: context
            ))
        }
        return runs
    }

    // Successful runs only (F6) — nil when the alias has none in this directory
    func summary(cwd: String, alias: String) -> RunSummary? {
        let durations = successfulDurations(cwd: cwd, alias: alias)
        guard !durations.isEmpty else { return nil }
        return RunSummary(recentFirstDurations: durations)
    }

    func aliasesWithHistory(cwd: String) -> [String] {
        guard let db = connection() else { return [] }

        let sql = "SELECT DISTINCT alias_name FROM runs WHERE cwd = ? ORDER BY alias_name"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            reportError("prepare alias list", db)
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, cwd, -1, SQLITE_TRANSIENT)

        var names: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            names.append(text(statement, 0))
        }
        return names
    }

    func runCount(cwd: String, alias: String) -> Int {
        guard let db = connection() else { return 0 }

        let sql = "SELECT COUNT(*) FROM runs WHERE cwd = ? AND alias_name = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            reportError("prepare run count", db)
            return 0
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, cwd, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, alias, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    // The baseline a just-finished run is compared against. Called before that run is
    // recorded, so it never pollutes its own baseline.
    func priorSuccessfulDurations(cwd: String, alias: String, limit: Int) -> [Int] {
        Array(successfulDurations(cwd: cwd, alias: alias).prefix(limit))
    }

    // Most recent first, so the trend windows slice straight off the front.
    // Ordered by id, not started_at: insertion order survives a backward clock step (F5).
    private func successfulDurations(cwd: String, alias: String) -> [Int] {
        guard let db = connection() else { return [] }

        let sql = """
        SELECT duration_ms FROM runs WHERE cwd = ? AND alias_name = ? AND exit_code = 0
        ORDER BY id DESC
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            reportError("prepare summary select", db)
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, cwd, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, alias, -1, SQLITE_TRANSIENT)

        var durations: [Int] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            durations.append(Int(sqlite3_column_int64(statement, 0)))
        }
        return durations
    }

    private func connection() -> OpaquePointer? {
        if openAttempted { return db }
        openAttempted = true

        do {
            try TelemetryPaths.prepareRoot()
        } catch {
            printError("Could not create telemetry directory: \(error.localizedDescription)")
            return nil
        }

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(TelemetryPaths.databaseURL.path, &handle, flags, nil) == SQLITE_OK, let handle else {
            printError("Could not open run history database.")
            if handle != nil { sqlite3_close(handle) }
            return nil
        }

        // WAL + busy_timeout let concurrent ez processes write without SQLITE_BUSY.
        // busy_timeout goes first: the journal_mode switch itself needs a lock.
        exec("PRAGMA busy_timeout=2000;", on: handle)
        exec("PRAGMA journal_mode=WAL;", on: handle)

        guard migrate(handle) else {
            sqlite3_close(handle)
            return nil
        }

        db = handle
        return db
    }

    private func migrate(_ handle: OpaquePointer) -> Bool {
        var version: Int32 = 0
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(handle, "PRAGMA user_version;", -1, &statement, nil) == SQLITE_OK,
           sqlite3_step(statement) == SQLITE_ROW {
            version = sqlite3_column_int(statement, 0)
        }
        sqlite3_finalize(statement)

        // Each step stamps its own literal version inside the same transaction as its DDL,
        // so user_version can never run ahead of the schema it describes
        if version < 1 {
            guard exec("""
            BEGIN IMMEDIATE;
            CREATE TABLE IF NOT EXISTS runs (
                id INTEGER PRIMARY KEY,
                cwd TEXT NOT NULL,
                alias_name TEXT NOT NULL,
                command_template TEXT NOT NULL,
                execution_type TEXT NOT NULL,
                exit_code INTEGER NOT NULL,
                duration_ms INTEGER NOT NULL,
                started_at INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS runs_lookup ON runs (cwd, alias_name, started_at);
            PRAGMA user_version=1;
            COMMIT;
            """, on: handle) else {
                reportError("migrate to schema v1", handle)
                exec("ROLLBACK;", on: handle)
                return false
            }
        }
        // v2: machine + boot context, nullable so pre-v2 rows stay valid
        if version < 2 {
            guard exec("""
            BEGIN IMMEDIATE;
            ALTER TABLE runs ADD COLUMN machine_id TEXT;
            ALTER TABLE runs ADD COLUMN hw_model TEXT;
            ALTER TABLE runs ADD COLUMN cpu_brand TEXT;
            ALTER TABLE runs ADD COLUMN perf_cores INTEGER;
            ALTER TABLE runs ADD COLUMN efficiency_cores INTEGER;
            ALTER TABLE runs ADD COLUMN memory_bytes INTEGER;
            ALTER TABLE runs ADD COLUMN os_version TEXT;
            ALTER TABLE runs ADD COLUMN runs_since_boot INTEGER;
            PRAGMA user_version=2;
            COMMIT;
            """, on: handle) else {
                reportError("migrate to schema v2", handle)
                exec("ROLLBACK;", on: handle)
                return false
            }
        }
        return true
    }

    @discardableResult
    private func exec(_ sql: String, on handle: OpaquePointer) -> Bool {
        sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK
    }

    private func text(_ statement: OpaquePointer?, _ column: Int32) -> String {
        guard let value = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: value)
    }

    private func reportError(_ action: String, _ handle: OpaquePointer) {
        printError("Run history (\(action)) failed: \(String(cString: sqlite3_errmsg(handle)))")
    }
}
