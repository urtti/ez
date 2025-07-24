import Foundation

struct AliasCollection: Codable {
    let aliases: [String: Alias]

    init(scope: Scope) {
        let fileURL = scope.getURL()
        // Check if the file exists
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            self = AliasCollection()
        } else {
            do {
                let data = try Data(contentsOf: fileURL)
                self = try JSONDecoder().decode(AliasCollection.self, from: data)
            } catch {
                printError("Failed to decode alias collection \(fileURL.absoluteString): \(error.localizedDescription)")
                Foundation.exit(1)
            }
        }
    }

    // Retrieve an alias by name
    func alias(for name: String) -> Alias? {
        return aliases[name]
    }

    // Add a new alias, returning a new AliasCollection instance
    func addAlias(name: String, alias: Alias) -> AliasCollection {
        var newAliases = aliases
        newAliases[name] = alias
        return AliasCollection(aliases: newAliases)
    }

    // Remove an alias, returning a new AliasCollection instance

    func longestAliasName() -> Int {
        aliases.max(by: { $0.key.count < $1.key.count })?.key.count ?? 0
    }

    var isEmpty: Bool {
        aliases.isEmpty
    }

    private init(aliases: [String: Alias] = [:]) {
        self.aliases = aliases
    }

    // Retrieve an alias by name
    private func hasAlias(called name: String) -> Bool {
        return aliases[name] != nil
    }

    private func remove(named name: String) -> AliasCollection {
        var newAliases = aliases
        newAliases.removeValue(forKey: name)
        return AliasCollection(aliases: newAliases)
    }

    private func storeToDisk(url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            try encoder.encode(self).write(to: url)
        } catch {
            printError("Encountered error: \(error)")
        }
    }

    static func addAlias(name: String, alias: Alias, scope: Scope) {
        AliasCollection(scope: scope).addAlias(name: name, alias: alias).storeToDisk(url: scope.getURL())
        print("🐘 \("ez \(name)".format(bold: true, color: .blue)) now stores \(alias.commandsDescription.format(bold: true, color: .blue)). \(scope.runContextDescription()) with \("ez \(name)".format(bold: true, color: .blue)).")
    }

    static func removeAlias(name: String, scope: Scope) {
        let collection = AliasCollection(scope: scope)
        if collection.hasAlias(called: name) {
            collection.remove(named: name).storeToDisk(url: scope.getURL())
            print("🐘 \("ez \(name)".format(bold: true, color: .blue)) removed.")
        } else {
            printError("No alias named '\(name)'.")
            return
        }
    }
}
