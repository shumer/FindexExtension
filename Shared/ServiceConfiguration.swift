import Foundation

struct ServiceConfiguration: Sendable {
    let team: String
    let bundlePrefix: String
    let group: String
    let service: String

    init(bundle: Bundle = .main) throws {
        guard bundle.object(forInfoDictionaryKey: "FinderPackBuildKind") as? String == "developer-id",
              let team = bundle.object(forInfoDictionaryKey: "FinderPackTeam") as? String,
              team.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) != nil,
              let prefix = bundle.object(forInfoDictionaryKey: "FinderPackBundlePrefix") as? String,
              prefix.range(of: "^[A-Za-z0-9]+(\\.[A-Za-z0-9-]+)+$", options: .regularExpression) != nil,
              let group = bundle.object(forInfoDictionaryKey: "FinderPackGroup") as? String,
              group == "\(team).\(prefix)",
              let service = bundle.object(forInfoDictionaryKey: "FinderPackService") as? String,
              service == "\(group).agent" else {
            throw ConfigurationError.missingSigningConfiguration
        }
        self.team = team
        self.bundlePrefix = prefix
        self.group = group
        self.service = service
    }

    var agentRequirement: String { requirement(for: [bundlePrefix + ".agent"]) }
    var clientRequirement: String { requirement(for: [bundlePrefix, bundlePrefix + ".extension"]) }

    private func requirement(for identifiers: [String]) -> String {
        let choices = identifiers.map { "identifier \"\($0)\"" }.joined(separator: " or ")
        return "anchor apple generic and certificate leaf[subject.OU] = \"\(team)\" and (\(choices))"
    }
}

enum ConfigurationError: LocalizedError {
    case missingSigningConfiguration
    var errorDescription: String? {
        "Set a valid development team and matching identifiers, then rebuild the signed prototype."
    }
}
