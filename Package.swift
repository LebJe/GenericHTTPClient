// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "GenericHTTPClient",
	platforms: [.macOS(.v11), .iOS(.v15)],
	products: [
		// Products define the executables and libraries a package produces, and make them visible to other packages.
		.library(
			name: "GenericHTTPClient",
			targets: ["GenericHTTPClient"]
		),
		.library(
			name: "GHCAsyncHTTPClient",
			targets: ["GHCAsyncHTTPClient"]
		),
		.library(
			name: "GHCURLSession",
			targets: ["GHCURLSession"]
		),
	],
	dependencies: [
		// Dependencies declare other packages that this package depends on.

		// HTTP client library built on SwiftNIO
		.package(url: "https://github.com/swift-server/async-http-client.git", from: "1.11.1"),

		// Event-driven network application framework for high performance protocol servers & clients, non-blocking.
		.package(url: "https://github.com/apple/swift-nio.git", from: "2.40.0"),
	],
	targets: [
		// Targets are the basic building blocks of a package. A target can define a module or a test suite.
		// Targets can depend on other targets in this package, and on products in packages this package depends on.
		.target(
			name: "GenericHTTPClient",
			dependencies: []
		),
		.target(
			name: "GHCAsyncHTTPClient",
			dependencies: [
				.target(name: "GenericHTTPClient"),
				.product(name: "AsyncHTTPClient", package: "async-http-client"),
				.product(name: "NIOHTTP1", package: "swift-nio"),
			]
		),
		.target(
			name: "GHCURLSession",
			dependencies: [
				.target(name: "GenericHTTPClient"),
			]
		),
		.testTarget(
			name: "GenericHTTPClientTests",
			dependencies: [
				.target(name: "GenericHTTPClient"),
				.target(name: "GHCAsyncHTTPClient"),
				.target(name: "GHCURLSession"),
			]
		),
	]
)
