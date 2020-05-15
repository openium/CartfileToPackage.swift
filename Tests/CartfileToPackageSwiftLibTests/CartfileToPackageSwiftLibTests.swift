import XCTest
@testable import CartfileToPackageSwiftLib

final class SingleLineDependencyTests: XCTestCase {

    func testSingleLineDependency_fromGithubLine() throws {
        let line = #"github "Alamofire/Alamofire" ~> 4.8"#
        let singleLineDep = SingleLineDependency.from(line: line)
        
        XCTAssertEqual(singleLineDep?.type, .github)
        XCTAssertEqual(singleLineDep?.computedUrl, "https://github.com/Alamofire/Alamofire")
        XCTAssertEqual(singleLineDep?.versionVerb, VersionVerb.upToNextMajor)
        XCTAssertEqual(singleLineDep?.versionOrBranchOrCommit, "4.8.0")
        XCTAssertEqual(singleLineDep?.toTargetLine(), "\"Alamofire\",")
        XCTAssertEqual(singleLineDep?.toPackageDependencyLine(), #".package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "4.8.0")),"#)
    }
    
    func testSingleLineDependency_fromGitLine() throws {
        let line = #"git "https://github.com/Alamofire/Alamofire" ~> 14.8"#
        let singleLineDep = SingleLineDependency.from(line: line)
        
        XCTAssertEqual(singleLineDep?.type, .git)
        XCTAssertEqual(singleLineDep?.computedUrl, "https://github.com/Alamofire/Alamofire")
        XCTAssertEqual(singleLineDep?.versionVerb, .upToNextMajor)
        XCTAssertEqual(singleLineDep?.versionOrBranchOrCommit, "14.8.0")
    }
    
    func testSingleLineDependency_fromLineWithBranch() throws {
        let line = #"git "https://github.com/openium/SwiftiumKit" "master""#
        let singleLineDep = SingleLineDependency.from(line: line)
        
        XCTAssertEqual(singleLineDep?.versionVerb, .branch)
        XCTAssertEqual(singleLineDep?.versionOrBranchOrCommit, "master")
    }

    func testSingleLineDependency_fromLineWithRevision() throws {
        let line = #"git "https://github.com/openium/SwiftiumKit" "44ba0f7aa793932d4a9df0804d11a9dbde644018""#
        let singleLineDep = SingleLineDependency.from(line: line)
        
        XCTAssertEqual(singleLineDep?.versionVerb, .revision)
        XCTAssertEqual(singleLineDep?.versionOrBranchOrCommit, "44ba0f7aa793932d4a9df0804d11a9dbde644018")
    }
    
    func testSingleLineDependency_fromLineWithBinary() throws {
        let line = #"binary "/absolute/path/MyFramework.json" ~> 2.3"#
        let singleLineDep = SingleLineDependency.from(line: line)
        
        XCTAssertEqual(singleLineDep?.type, .binary)
        XCTAssertEqual(singleLineDep?.versionVerb, .upToNextMajor)
        XCTAssertEqual(singleLineDep?.versionOrBranchOrCommit, "2.3.0")
    }
    
    func testSingleLineDependency_fromLineWithGithubEnterpriseOnMaster() throws {
        let line = #"github "https://enterprise.local/ghe/desktop/git-error-translations""#
        let singleLineDep = SingleLineDependency.from(line: line)
        
        XCTAssertEqual(singleLineDep?.type, .github)
        XCTAssertEqual(singleLineDep?.versionVerb, .branch)
        XCTAssertEqual(singleLineDep?.versionOrBranchOrCommit, "master")
    }
    
    
    func testSingleLineDependency_fromLineWithComment_shouldReturnNil() throws {
        let line = #"## https://github.com/tristanhimmelman/AlamofireObjectMapper/issues/120"#
        let singleLineDep = SingleLineDependency.from(line: line)
        
        XCTAssertNil(singleLineDep)
    }
    
    func testSingleLineDependency_fromLineWithCommentedDependency_shouldReturnNil() throws {
        let line = #"## github "ReactiveCocoa/ReactiveCocoa" >= 2.3.1"#
        let singleLineDep = SingleLineDependency.from(line: line)
        
        XCTAssertNil(singleLineDep)
    }
    
    func testSingleLineDependency_toPackageDependencyLine_shouldGenerateCommentedCode() throws {
        let line = #"binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseAnalyticsBinary.json""#
        
        let singleLineDep = SingleLineDependency.from(line: line)
        
        XCTAssertEqual(singleLineDep?.toPackageDependencyLine(), "// binary not managed yet for : https://dl.google.com/dl/firebase/ios/carthage/FirebaseAnalyticsBinary.json")
    }
}

final class CartfileToPackageSwiftTests: XCTestCase {
    
    func testCartfileToPackageSwift_computePackageName() throws {
        let psc = CartfileToPackageSwift(fromCartfileSwiftFilePath: "/tmp/path/to/AppDependencies/Cartfile", packagePath: "/tmp/path/to/AppDependenciesPackage")
        
        XCTAssertEqual(psc.packageName, "AppDependenciesPackage")
    }
    
    func testCartfileToPackageSwift_applyConfigurationLines_withCartfileExample() throws {
        let psc = CartfileToPackageSwift(fromCartfileSwiftFilePath: "/tmp/path/to/AppDependencies/Cartfile", packagePath: "/tmp/path/to/AppDependenciesPackage")
        // Cartfile file from https://github.com/Carthage/Carthage/blob/master/Documentation/Artifacts.md#cartfile
        let lines = """
        # Require version 2.3.1 or later
        github "ReactiveCocoa/ReactiveCocoa" >= 2.3.1

        # Require version 1.x
        github "Mantle/Mantle" ~> 1.0    # (1.0 or later, but less than 2.0)

        # Require exactly version 0.4.1
        github "jspahrsummers/libextobjc" == 0.4.1

        # Use the latest version
        github "jspahrsummers/xcconfigs"

        # Use the branch
        github "jspahrsummers/xcconfigs" "branch"

        # Use a project from GitHub Enterprise
        github "https://enterprise.local/ghe/desktop/git-error-translations"

        # Use a project from any arbitrary server, on the "development" branch
        git "https://enterprise.local/desktop/git-error-translations2.git" "development"

        # Use a local project
        git "file:///directory/to/project" "branch"

        # A binary only framework
        binary "https://my.domain.com/release/MyFramework.json" ~> 2.3

        # A binary only framework via file: url
        binary "file:///some/local/path/MyFramework.json" ~> 2.3

        # A binary only framework via local relative path from Current Working Directory to binary project specification
        binary "relative/path/MyFramework.json" ~> 2.3

        # A binary only framework via absolute path to binary project specification
        binary "/absolute/path/MyFramework.json" ~> 2.3
        """
        
        psc.applyConfiguration(lines: lines)
        
        XCTAssertEqual(psc.singleLineDependencies.count, 24)
        XCTAssertEqual(psc.packageDependencies.count, 24)
    }
    
    func testCartfileToPackageSwift_applyConfigurationLines_withBigCartfile() throws {
        let psc = CartfileToPackageSwift(fromCartfileSwiftFilePath: "/tmp/path/to/AppDependencies/Cartfile", packagePath: "/tmp/path/to/AppDependenciesPackage")
        // Cartfile file from https://github.com/Carthage/Carthage/blob/master/Documentation/Artifacts.md#cartfile
        let lines = """
        github "Alamofire/Alamofire" ~> 4.8
        github "tristanhimmelman/ObjectMapper" ~> 3.5
        github "radex/SwiftyUserDefaults" ~> 4.0
        github "realm/realm-cocoa" ~> 4.1.1
        github "onevcat/Kingfisher" ~> 5.11
        github "RxSwiftCommunity/RxAlamofire" ~> 5.1
        github "ReactiveX/RxSwift" ~> 5.0
        github "RxSwiftCommunity/RxSwiftExt" ~> 5.2
        github "RxSwiftCommunity/RxRealm" ~> 2.0
        github "SwiftyBeaver/SwiftyBeaver" ~> 1.7
        github "Skyscanner/SkyFloatingLabelTextField" ~> 3.7
        github "apollographql/apollo-ios" ~> 0.27
        github "malcommac/SwiftDate" ~> 6.0
        github "ivanvorobei/SPPermission" ~> 4.0
        github "ArtSabintsev/Siren" ~> 5.1
        github "marmelroy/PhoneNumberKit" ~> 3.0
        github "WenchaoD/FSPagerView" ~> 0.8
        github "psharanda/Atributika" ~> 4.9
        github "roberthein/TinyConstraints" ~> 4.0
        github "airbnb/lottie-ios" ~> 2.5
        github "evgenyneu/Cosmos" ~> 21.0
        github "tristanhimmelman/AlamofireObjectMapper" ~> 5.2
        github "Alamofire/AlamofireNetworkActivityIndicator" ~> 2.4
        binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseAnalyticsBinary.json"
        binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseAuthBinary.json"
        binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseMessagingBinary.json"
        binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseDynamicLinksBinary.json"
        binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseFirestoreBinary.json"
        binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseStorageBinary.json"
        binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseRemoteConfigBinary.json"
        binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseProtobufBinary.json"
        github "SVProgressHUD/SVProgressHUD" ~> 2.2
        github "AlbertArredondoAlfaro/SwiftValidator" "swift-5.0"
        github "openium/SwiftiumTestingKit" ~> 0.6
        github "eddiekaiger/SwiftyAttributes" ~> 5.1
        github "SwiftKickMobile/SwiftMessages" ~> 7.0
        github "maxep/MXParallaxHeader" ~> 1.1
        github "ElaWorkshop/TagListView" ~> 1.4
        github "xmartlabs/XLPagerTabStrip" ~> 9.0
        github "stripe/stripe-ios" ~> 19.0
        github "RxSwiftCommunity/RxDataSources" ~> 4.0
        github "MessageKit/MessageKit" ~> 3.0
        github "zvonicek/ImageSlideshow" ~> 1.8
        github "ivanbruel/MarkdownKit" ~> 1.5
        binary "https://www.mapbox.com/ios-sdk/Mapbox-iOS-SDK.json" ~> 5.8
        github "mapbox/mapbox-events-ios" ~> 0.10
        """
        
        psc.applyConfiguration(lines: lines)
        
        XCTAssertEqual(psc.singleLineDependencies.count, 46)
        XCTAssertEqual(psc.packageDependencies.count, 46)
    }
    
}
