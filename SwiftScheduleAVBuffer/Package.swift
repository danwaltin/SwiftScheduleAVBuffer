// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftScheduleAVBuffer",
	platforms: [
		.macOS(.v13),
	],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "SwiftScheduleAVBuffer",
			resources: [
				.process("Rhythm.caf"),
				.process("bjekker.m4a"),
				.process("bjekker-rateChanged_0.m4a"),
				.process("bjekker-rateChanged_1.m4a")]),
    ]
)

