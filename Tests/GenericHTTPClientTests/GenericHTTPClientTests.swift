// Copyright (c) 2022 Jeff Lebrun
//
//  Licensed under the MIT License.
//
//  The full text of the license can be found in the file named LICENSE.

import Foundation
@testable import GenericHTTPClient
import GHCAsyncHTTPClient
import GHCURLSession
import XCTest

final class GenericHTTPClientTests: XCTestCase {
	@MainActor func testExample() async throws {
		let data = """
		{"string": "Hello, World"}
		"""

		let req = GHCHTTPRequest(
			url: URL(string: "https://httpbin.org/anything")!,
			method: .POST,
			headers: ["Content-Type": "application/json"],
			body: .string(data)
		)

		let urlSessionClient = URLSessionHTTPClient()
		let ahcClient = AHCHTTPClient()
		defer {
			ahcClient.shutdown()
		}

		let res = try await urlSessionClient.send(request: req)
		let res2 = try await ahcClient.send(request: req)

		for r in [res, res2] {
			if let body = r.body {
				let decoded = try JSONDecoder().decode(Response.self, from: Data(body))
				XCTAssertEqual(decoded.data, data)
				XCTAssertEqual(decoded.headers["Content-Type"], "application/json")
			} else {
				XCTFail("Response body is nil!")
			}
		}
	}
}

extension String {
	/// Initialize `String` from an array of bytes.
	init(_ bytes: [UInt8]) {
		self = String(bytes.map({ Character(Unicode.Scalar($0)) }))
	}
}

struct Response: Decodable {
	let headers: [String: String]
	let data: String
}
