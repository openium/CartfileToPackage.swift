import Foundation

enum DependencyType: String {
    case git
    case github
    case binary
    
    var prefix: String {
        if self == .github { return "https://github.com/" }
        return ""
    }
}

protocol ToPackageLineable {
    func toTargetLine() -> String
    func toPackageDependencyLine() -> String
}

enum VersionVerb: String {
    case from
    case upToNextMajor
    case upToNextMinor
    case branch
    case revision
    case exact
    
    init?(rawValue: String) {
        switch rawValue {
        case "upToNextMajor", "~>":
            self = .upToNextMajor
        case "upToNextMinor":
            self = .upToNextMinor
        case "branch":
            self = .branch
        case "revision", "commit", "==":
            self = .revision
        case "exact":
            self = .exact
        case "from", ">=":
            self = .from
        default:
            return nil
        }
    }
    
    func toPackageSwiftVersion(_ versionOrBranchOrCommit: String) -> String {
        switch self {
        case .upToNextMajor, .upToNextMinor:
            return ".\(self.rawValue)(from: \"\(versionOrBranchOrCommit)\")"
        case .from:
            return ".\(self.rawValue): \"\(versionOrBranchOrCommit)\""
        case .exact, .revision, .branch:
            return ".\(self.rawValue)(\"\(versionOrBranchOrCommit)\")"
        }
    }
}

struct SingleLineDependency: ToPackageLineable {
    let type: DependencyType
    let urlOrGithubUserRepo: String
    let versionVerb: VersionVerb
    let versionOrBranchOrCommit: String

    var computedTargetName: String {
        return urlOrGithubUserRepo.components(separatedBy: "/").last ?? urlOrGithubUserRepo
    }
    
    var computedUrl: String {
        if urlOrGithubUserRepo.hasPrefix("http") { return urlOrGithubUserRepo }
        return type.prefix + urlOrGithubUserRepo
    }
    
    static func from(line: String) -> SingleLineDependency? {
        // https://nshipster.com/swift-regular-expressions/
        let pattern = #"""
        (?xi)
        (^(?<type>git|github|binary))
        \s
        "((?<urlOrGithubUserRepo>[a-zA-Z0-9-_~:\/@\.]+))"
        \s?
        (?-x:((?<versionVerb>~>|==|>=)\s)?)
        (?-x:((?<versionOrBranchOrCommit>["a-zA-Z0-9-_\.]+))?)
        """#
        let regex = try! NSRegularExpression(pattern: pattern)
        let nsrange = NSRange(line.startIndex..<line.endIndex, in: line)
        
        guard let match = regex.firstMatch(in: line, options: [], range: nsrange) else {
            return nil
        }
        
        guard let typeStr = match.textOfRange(withName: "type", in: line),
            let type = DependencyType(rawValue: typeStr),
            let urlOrGithubUserRepo = match.textOfRange(withName: "urlOrGithubUserRepo", in: line)
            else {
                return nil
        }
        var versionVerb: VersionVerb = .branch
        if let versionVerbString = match.textOfRange(withName: "versionVerb", in: line) {
            guard let vv = VersionVerb(rawValue: versionVerbString) else {
                return nil
            }
            versionVerb = vv
        }
        
        var versionOrBranchOrCommit = "master"
        if let parsedOne = match.textOfRange(withName: "versionOrBranchOrCommit", in: line)?.replacingOccurrences(of: "\"", with: "") {
            versionOrBranchOrCommit = parsedOne
        }
        
        let exampleGitSha = "44ba0f7aa793932d4a9df0804d11a9dbde644018"
        if versionOrBranchOrCommit.hasOnlyBase16Characters && versionOrBranchOrCommit.count == exampleGitSha.count {
            versionVerb = .revision
        }
        
        let dotsOnly = versionOrBranchOrCommit.replacingOccurrences(of: "[1234567890]", with: "", options: [.regularExpression, .caseInsensitive])
        if dotsOnly == "." { // versionOrBranchOrCommit => 5.4 or 12.5
            versionOrBranchOrCommit.append(".0") // append semver patch
        }
        
        return SingleLineDependency(type: type,
                                    urlOrGithubUserRepo: urlOrGithubUserRepo,
                                    versionVerb: versionVerb,
                                    versionOrBranchOrCommit: versionOrBranchOrCommit)
    }
    
    func toTargetLine() -> String {
        if type == .binary { return "// binary not managed yet for : \(computedUrl)" }
        return "\"\(computedTargetName)\","
    }
    
    func toPackageDependencyLine() -> String {
        if type == .binary { return "// binary not managed yet for : \(computedUrl)" }
        return """
            .package(url: "\(computedUrl)", \(versionVerb.toPackageSwiftVersion(versionOrBranchOrCommit))),
            """
    }
}

struct CommentLine: ToPackageLineable {
    let line: String
    func toTargetLine() -> String {
        return "// " + line
    }
    
    func toPackageDependencyLine() -> String {
        return "// " + line
    }
}

extension NSTextCheckingResult {
    func textOfRange(withName name: String, in text: String) -> String? {
        var result: String?
        if #available(OSX 10.13, *) {
            let nsrange = range(withName: name)
            if nsrange.location != NSNotFound, let inrange = Range(nsrange, in: text) {
                result = String(text[inrange])
            }
        } else {
            fatalError("linux not managed yet")
        }
        return result
    }
}

extension String {
    var hasOnlyBase16Characters: Bool {
        let someString = self.replacingOccurrences(of: "[1234567890abcdef]", with: "", options: [.regularExpression, .caseInsensitive])
        return someString.isEmpty
    }
    
    func containsCharacters(in characters: String) -> Bool {
        for character in characters {
            if self.contains(character) {
                return true
            }
        }
        return false
    }
}

public class CartfileToPackageSwift {
    let fromCartfileSwiftFilePath: String
    let packagePath: String
    
    var singleLineDependencies = [ToPackageLineable]()
    
    public init(fromCartfileSwiftFilePath: String, packagePath: String) {
        self.fromCartfileSwiftFilePath = fromCartfileSwiftFilePath
        self.packagePath = packagePath
    }
    
    func readConfigurationFile() throws {
        let lines = try String(contentsOfFile: fromCartfileSwiftFilePath)
        applyConfiguration(lines: lines)
    }
    
    func applyConfiguration(lines: String) {
        lines.components(separatedBy: .newlines).enumerated().forEach { (e) in
            guard e.element.isEmpty == false else { return }
            if e.element.hasPrefix("#") {
                let commentLine = CommentLine(line: e.element)
                singleLineDependencies.append(commentLine)
            } else {
                guard let singleLineDependency = SingleLineDependency.from(line: e.element) else {
                    fatalError("can't parse dependency line \(e.element) in \(fromCartfileSwiftFilePath):\(e.offset)")
                }
                singleLineDependencies.append(singleLineDependency)
            }
        }
    }
    
    lazy var packageName: String = {
        var pathComponents = packagePath.components(separatedBy: "/")
        return pathComponents.last ?? "Unknown"
    }()
    
    public lazy var targetsLines: [String] = {
        return singleLineDependencies.map { (singleLineDep) -> String in
            return singleLineDep.toTargetLine()
        }
    }()

    lazy var packageDependencies: [String] = {
        return singleLineDependencies.map { (singleLineDep) -> String in
            return singleLineDep.toPackageDependencyLine()
        }
    }()

    public func generatePackage() throws {
        try readConfigurationFile()
        // Remove oldies
        let fm = FileManager.default
        if fm.fileExists(atPath: packagePath) {
            try fm.removeItem(atPath: packagePath)
        }
        try fm.createDirectory(atPath: packagePath, withIntermediateDirectories: true, attributes: .none)
        fm.createFile(atPath: packagePath + "/Empty.swift", contents: nil, attributes: .none)
        fm.createFile(atPath: packagePath + "/Package.swift", contents: getPackageSwiftFileContent().data(using: .utf8), attributes: .none)
    }
    
    func getPackageSwiftFileContent() -> String {
        return """
        // swift-tools-version:5.2
        // The swift-tools-version declares the minimum version of Swift required to build this package.
        // https://github.com/apple/swift-package-manager/blob/master/Documentation/PackageDescription.md
        // Initially generated with ❤️ with CartfileToPackage.swift
        
        import PackageDescription
        \(generateWarnings())
        let package = Package(
            name: "\(packageName)",
            //platforms: [ .macOS(.v10_10), .iOS(.v8), .tvOS(.v9), .watchOS(.v2), ],
            products: [
                .library(
                    name: "\(packageName)",
                    type: .dynamic,
                    targets: ["\(packageName)"]),
            ],
            dependencies: [
                    \(packageDependencies.joined(separator: "\n            "))
                ],
            targets: [
                .target(
                    name: "\(packageName)",
                    dependencies: [
                        \(targetsLines.joined(separator: "\n                "))
                    ],
                    path: ".",
                    sources: ["Empty.swift"]),
            ]
        )
        """
        
    }
    
    func generateWarnings() -> String {
        let targetNamesWithSpecialCharacters = singleLineDependencies.compactMap { $0 as? SingleLineDependency }
            .compactMap { (singleLineDep) -> String? in
                if singleLineDep.computedTargetName.containsCharacters(in: ".-") {
                    return singleLineDep.computedTargetName
                }
                return nil
        }
        
        if targetNamesWithSpecialCharacters.count == 0 {
            return ""
        }
        let warnings = """
        Some package(s) have name that might not be correct, you should fix them
        exemple fixes in both package and target:
           realm-cocoa -> Realm
           JWTDecode.swift -> JWTDecode)
        Concerned package(s):
            \(targetNamesWithSpecialCharacters.joined(separator: "    \n"))
        """
        return "#warning(\"\"\"\n\(warnings)\n\"\"\")"
    }
}

