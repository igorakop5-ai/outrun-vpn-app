// swift-tools-version: 5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
     name: "Outrun VPN Packages",
     platforms: [
        // Minimum platform version
         .iOS(.v13)
     ],
     products: [
         .library(
             name: "Outrun VPNCore",
             targets: ["Outrun VPNCore"]),
     ],
     dependencies: [
         // No dependencies
     ],
     targets: [
        .binaryTarget(
            name: "Outrun VPNCore",
            path: "../Frameworks/Outrun VPNCore.xcframework"
        )
     ]
 )
