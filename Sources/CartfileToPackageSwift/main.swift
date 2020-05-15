import Foundation
import CartfileToPackageSwiftLib

var pathToCartfile: String!
var packagePath: String

func usage() -> Never {
    let help = """
    usage : CartfileToPackage.swift /tmp/some/path/to/Cartfile /tmp/some/path/to/YourDependenciesPackageDirectory
    """
    print(help)
    exit(0)
}

var arguments = CommandLine.arguments
arguments.removeFirst() // binary path
guard arguments.count > 0 else { usage() }
pathToCartfile = arguments.remove(at: 0)

guard arguments.count > 0 else { usage() }
packagePath = arguments.remove(at: 0)

let cartfileToPackage = CartfileToPackageSwift(fromCartfileSwiftFilePath: pathToCartfile, packagePath: packagePath)

do {
    try cartfileToPackage.generatePackage()
} catch {
    print("error: \(error.localizedDescription)")
    exit(12)
}

print("""
You can now drag & drop the package in your project/workspace or run:
    cd \(packagePath) && swift build
Please remember that the Package.swift might be incorrect, you can find help in the SPM documentation at:
https://github.com/apple/swift-package-manager/blob/master/Documentation
""")
