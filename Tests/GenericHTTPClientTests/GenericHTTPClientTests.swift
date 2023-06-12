// Copyright (c) 2022 Jeff Lebrun
//
//  Licensed under the MIT License.
//
//  The full text of the license can be found in the file named LICENSE.

import Foundation
@testable import GenericHTTPClient
import GHCAsyncHTTPClient
import GHCURLSession
import Logging
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
		let ahcClient = AHCHTTPClient(client: .init(eventLoopGroupProvider: .createNew))
		defer {
			ahcClient.shutdown()
		}

		let res = await urlSessionClient.send(request: req)
		let res2 = await ahcClient.send(request: req)

		var resultsArray: [GHCHTTPResponse] = []

		switch res {
			case let .success(response): resultsArray.append(response)
			case let .failure(error): XCTFail("Unexpected error: \(error.localizedDescription)")
		}

		switch res2 {
			case let .success(response): resultsArray.append(response)
			case let .failure(error): XCTFail("Unexpected error: \(error.localizedDescription)")
		}

		for r in resultsArray {
			if let body = r.body {
				let decoded = try JSONDecoder().decode(Response.self, from: Data(body))
				XCTAssertEqual(decoded.json.string, "Hello, World")
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
	let json: Json

	struct Json: Decodable {
		let string: String
	}
}
