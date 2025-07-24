import Foundation

@MainActor var childProcesses: [Int32: Process] = .init()

@MainActor func runCommands(_ command: String, output: FileHandle = .standardOutput, errorOutput: FileHandle = .standardError) {
    let process = Process()
    let shell = "/bin/zsh"
    process.executableURL = URL(fileURLWithPath: shell)
    process.arguments = ["-c", command]

    // Forward the standard input, output, and error
    process.standardInput = FileHandle.standardInput
    process.standardOutput = output
    process.standardError = errorOutput

    do {
        let start = Date()
        // Code to be timed
        try process.run()
        childProcesses[process.processIdentifier] = process
        // TODO: Print this when verbose, noisy otherwise
        // print("Started [PID:\(process.processIdentifier)] \(command)...")
        process.waitUntilExit()
        childProcesses.removeValue(forKey: process.processIdentifier)
        printTimeTaken(fromStart: start)
    } catch {
        printError("Failed to execute command: \(error.localizedDescription)")
    }
}

func runParallelCommands(_ commands: [String], output: FileHandle = .standardOutput, errorOutput: FileHandle = .standardError) async {
    print("🐘 Running in parallel: \(commands.joined(separator: ", "))".format(bold: true, color: .green))
    fflush(stdout) // Ensures the text is flushed immediately to the console
    await withTaskGroup(of: Void.self) { taskGroup in
        for command in commands {
            taskGroup.addTask {
                await runSingleParallelJob(command, output: output, errorOutput: errorOutput)
            }
        }
    }
}

private func runSingleParallelJob(_ command: String, output: FileHandle = .standardOutput, errorOutput: FileHandle = .standardError) async {
    let process = Process()
    let shell = "/bin/zsh"
    process.executableURL = URL(fileURLWithPath: shell)
    process.arguments = ["-c", command]

    // Set up a pipe to capture output
    // let outputPipe = Pipe()
    // TODO: Consider if it would make sense to capture outputs and e.g. output when job is done
    process.standardInput = FileHandle.standardInput
    process.standardOutput = output
    process.standardError = errorOutput

    do {
        let start = Date()
        try process.run()
        _ = await MainActor.run {
            childProcesses[process.processIdentifier] = process
        }
        print("Started [PID:\(process.processIdentifier)] \(command)...")
        process.waitUntilExit()
        _ = await MainActor.run {
            childProcesses.removeValue(forKey: process.processIdentifier)
        }
        printTimeTaken(fromStart: start, jobTitle: "[PID:\(process.processIdentifier)] \(command) ",)
        fflush(stdout) // Ensures the text is flushed immediately to the console
    } catch {
        printError("Failed to execute command: \(error.localizedDescription)")
    }
}
