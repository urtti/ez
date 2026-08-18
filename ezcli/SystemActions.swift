import Foundation

@MainActor var childPids: Set<pid_t> = []

// Secrets ride in the child's environment instead of argv, so resolved values never show
// up in the process table (`ps`). An inherited variable with the same name is replaced,
// so the Keychain value always wins. Caller frees every entry.
private func makeSpawnEnvironment(secrets: [String: String]) -> [UnsafeMutablePointer<CChar>?] {
    var entries: [UnsafeMutablePointer<CChar>?] = []
    var i = 0
    while let entry = environ[i] {
        let text = String(cString: entry)
        let name = String(text.prefix(while: { $0 != "=" }))
        if secrets[name] == nil {
            entries.append(strdup(text))
        }
        i += 1
    }
    for (key, value) in secrets {
        entries.append(strdup("\(key)=\(value)"))
    }
    entries.append(nil)
    return entries
}

// Returns the exit code the alias produced. Spawn failure is 126, an unwaitable child is 1.
@MainActor func runCommands(_ command: String, aliasName: String, commandTemplate: String, secrets: [String: String]) async -> Int32 {
    let start = Date()
    let clock = ContinuousClock()
    let begin = clock.now

    let shell = "/bin/zsh"
    var pid: pid_t = 0

    // Set up posix_spawn to inherit file descriptors (including TTY)
    var fileActions: posix_spawn_file_actions_t?
    posix_spawn_file_actions_init(&fileActions)

    // Inherit stdin/stdout/stderr (file descriptors 0, 1, 2)
    posix_spawn_file_actions_adddup2(&fileActions, STDIN_FILENO, STDIN_FILENO)
    posix_spawn_file_actions_adddup2(&fileActions, STDOUT_FILENO, STDOUT_FILENO)
    posix_spawn_file_actions_adddup2(&fileActions, STDERR_FILENO, STDERR_FILENO)

    // Build args array
    let args: [UnsafeMutablePointer<CChar>?] = [
        strdup(shell),
        strdup("-c"),
        strdup(command),
        nil
    ]
    defer {
        for arg in args { free(arg) }
    }

    let envp = makeSpawnEnvironment(secrets: secrets)
    defer {
        for entry in envp { free(entry) }
    }

    let result = posix_spawn(&pid, shell, &fileActions, nil, args, envp)
    posix_spawn_file_actions_destroy(&fileActions)

    if result == 0 {
        childPids.insert(pid)
        var status: Int32 = 0
        let waited = waitpid(pid, &status, 0)
        childPids.remove(pid)
        let elapsedMs = milliseconds(from: clock.now - begin)
        // A failed wait leaves status unwritten, so there is no exit code worth recording
        guard waited == pid else {
            printTimeTaken(fromStart: start)
            printError("Could not wait for process \(pid): \(String(cString: strerror(errno)))")
            return 1
        }
        let code = exitCode(fromStatus: status)
        // Read before recording this run, so it never pollutes its own baseline
        let note = code == 0 ? await outlierNote(aliasName: aliasName, durationMs: elapsedMs) : nil
        printTimeTaken(fromStart: start, suffix: note ?? "")
        await recordRun(
            aliasName: aliasName,
            commandTemplate: commandTemplate,
            executionType: .sequential,
            exitCode: code,
            durationMs: elapsedMs,
            startedAt: start
        )
        return code
    } else {
        printError("Failed to spawn process: \(result)")
        return 126
    }
}

// displayCommands hold the pre-secret text, so resolved secrets stay out of the terminal.
// Returns the first non-zero exit code in command order, matching what gets recorded.
func runParallelCommands(_ commands: [String], displayCommands: [String], aliasName: String, commandTemplate: String, secrets: [String: String]) async -> Int32 {
    print("🐘 Running in parallel: \(displayCommands.joined(separator: ", "))".format(bold: true, color: .green))
    fflush(stdout)
    let start = Date()
    let clock = ContinuousClock()
    let begin = clock.now

    // One row per invocation: total wall time, first non-zero exit code in command order
    var codes = [Int32?](repeating: nil, count: commands.count)
    await withTaskGroup(of: (Int, Int32?).self) { taskGroup in
        for (index, command) in commands.enumerated() {
            let displayCommand = index < displayCommands.count ? displayCommands[index] : command
            taskGroup.addTask {
                (index, await runSingleParallelJob(command, displayCommand: displayCommand, secrets: secrets))
            }
        }
        for await (index, code) in taskGroup {
            codes[index] = code
        }
    }

    // A job with no known exit code makes the invocation uncharacterizable, so it is not
    // recorded — but the failure still has to surface, so ez exits non-zero
    guard !codes.contains(where: { $0 == nil }) else { return 1 }
    let aggregatedExitCode = codes.compactMap { $0 }.first(where: { $0 != 0 }) ?? 0
    let elapsedMs = milliseconds(from: clock.now - begin)

    // Sub-jobs print their own timings; the invocation total is only worth a line of its
    // own when it has something to say about the whole run
    if aggregatedExitCode == 0, let note = await outlierNote(aliasName: aliasName, durationMs: elapsedMs) {
        print("🐘⏱️ total \(formatDuration(milliseconds: elapsedMs))".format(bold: true, color: .green) + note)
        fflush(stdout)
    }

    await recordRun(
        aliasName: aliasName,
        commandTemplate: commandTemplate,
        executionType: .parallel,
        exitCode: aggregatedExitCode,
        durationMs: elapsedMs,
        startedAt: start
    )
    return aggregatedExitCode
}

// nil unless the run is slow enough to be worth commenting on and far enough from its
// baseline to be worth saying. Returns pre-coloured text ready to append to a timing line.
private func outlierNote(aliasName: String, durationMs: Int) async -> String? {
    // No duration gate here: whether this is worth saying depends on the baseline too,
    // which needs the query. It is one indexed read on a connection already open to record.
    let priors = await RunStore.shared.priorSuccessfulDurations(
        cwd: FileManager.default.currentDirectoryPath,
        alias: aliasName,
        limit: OUTLIER_BASELINE_WINDOW
    )
    guard let outlier = RunOutlier(durationMs: durationMs, priorDurations: priors) else { return nil }
    return "  " + outlier.note.format(bold: true, color: outlier.color)
}

// nil when the exit code could not be determined
private func runSingleParallelJob(_ command: String, displayCommand: String, secrets: [String: String]) async -> Int32? {
    let start = Date()
    let shell = "/bin/zsh"
    var pid: pid_t = 0

    var fileActions: posix_spawn_file_actions_t?
    posix_spawn_file_actions_init(&fileActions)
    posix_spawn_file_actions_adddup2(&fileActions, STDIN_FILENO, STDIN_FILENO)
    posix_spawn_file_actions_adddup2(&fileActions, STDOUT_FILENO, STDOUT_FILENO)
    posix_spawn_file_actions_adddup2(&fileActions, STDERR_FILENO, STDERR_FILENO)

    let args: [UnsafeMutablePointer<CChar>?] = [
        strdup(shell),
        strdup("-c"),
        strdup(command),
        nil
    ]
    defer {
        for arg in args { free(arg) }
    }

    let envp = makeSpawnEnvironment(secrets: secrets)
    defer {
        for entry in envp { free(entry) }
    }

    let result = posix_spawn(&pid, shell, &fileActions, nil, args, envp)
    posix_spawn_file_actions_destroy(&fileActions)

    if result == 0 {
        _ = await MainActor.run {
            childPids.insert(pid)
        }
        print("Started [PID:\(pid)] \(displayCommand)...")
        fflush(stdout)
        var status: Int32 = 0
        let waited = waitpid(pid, &status, 0)
        _ = await MainActor.run {
            childPids.remove(pid)
        }
        printTimeTaken(fromStart: start, jobTitle: "[PID:\(pid)] \(displayCommand) ")
        fflush(stdout)
        guard waited == pid else {
            printError("Could not wait for process \(pid): \(String(cString: strerror(errno)))")
            return nil
        }
        return exitCode(fromStatus: status)
    } else {
        printError("Failed to spawn process: \(result)")
        return nil
    }
}

// waitpid status: exited -> exit status, killed by a signal -> 128 + signal
private func exitCode(fromStatus status: Int32) -> Int32 {
    let terminationSignal = status & 0x7f
    if terminationSignal == 0 {
        return (status >> 8) & 0xff
    }
    return 128 + terminationSignal
}

// Rounded, so a sub-millisecond run is not stored as a flat 0 ms baseline
private func milliseconds(from duration: Duration) -> Int {
    let components = duration.components
    let subSecondMs = (components.attoseconds + 500_000_000_000_000) / 1_000_000_000_000_000
    return Int(components.seconds * 1000 + subSecondMs)
}

private func recordRun(aliasName: String, commandTemplate: String, executionType: ExecutionType, exitCode: Int32, durationMs: Int, startedAt: Date) async {
    await RunStore.shared.record(RunRecord(
        cwd: FileManager.default.currentDirectoryPath,
        aliasName: aliasName,
        commandTemplate: commandTemplate,
        executionType: executionType,
        exitCode: exitCode,
        durationMs: durationMs,
        startedAt: startedAt
    ))
}
