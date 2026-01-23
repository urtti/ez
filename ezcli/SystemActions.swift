import Foundation

@MainActor var childPids: Set<pid_t> = []

@MainActor func runCommands(_ command: String) {
    let start = Date()

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

    let result = posix_spawn(&pid, shell, &fileActions, nil, args, environ)
    posix_spawn_file_actions_destroy(&fileActions)

    if result == 0 {
        childPids.insert(pid)
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        childPids.remove(pid)
        printTimeTaken(fromStart: start)
    } else {
        printError("Failed to spawn process: \(result)")
    }
}

func runParallelCommands(_ commands: [String]) async {
    print("🐘 Running in parallel: \(commands.joined(separator: ", "))".format(bold: true, color: .green))
    fflush(stdout)
    await withTaskGroup(of: Void.self) { taskGroup in
        for command in commands {
            taskGroup.addTask {
                await runSingleParallelJob(command)
            }
        }
    }
}

private func runSingleParallelJob(_ command: String) async {
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

    let result = posix_spawn(&pid, shell, &fileActions, nil, args, environ)
    posix_spawn_file_actions_destroy(&fileActions)

    if result == 0 {
        _ = await MainActor.run {
            childPids.insert(pid)
        }
        print("Started [PID:\(pid)] \(command)...")
        fflush(stdout)
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        _ = await MainActor.run {
            childPids.remove(pid)
        }
        printTimeTaken(fromStart: start, jobTitle: "[PID:\(pid)] \(command) ")
        fflush(stdout)
    } else {
        printError("Failed to spawn process: \(result)")
    }
}
