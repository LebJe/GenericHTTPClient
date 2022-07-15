// Copyright (c) 2022 Jeff Lebrun
//
//  Licensed under the MIT License.
//
//  The full text of the license can be found in the file named LICENSE.

import struct Foundation.URL

public protocol GHCHTTPClient {
	func send(request: GHCHTTPRequest) async throws -> GHCHTTPResponse
	func shutdown()
}

public struct GHCHTTPRequest {
	public var url: URL
	public var method: GHCHTTPMethod
	public var headers: GHCHTTPHeaders = [:]
	public var body: [UInt8]?

	public init(url: URL, method: GHCHTTPMethod = .GET, headers: GHCHTTPHeaders = [:], body: Self.HTTPBody? = nil) {
		self.url = url
		self.method = method
		self.headers = headers
		if let body = body {
			switch body {
				case let .string(s):
					self.body = Array(s.utf8)
				case let .bytes(u):
					self.body = u
			}
		}
	}

	public enum HTTPBody {
		case string(String)
		case bytes([UInt8])
	}
}

public struct GHCHTTPHeaders: ExpressibleByDictionaryLiteral, Sequence {
	public typealias Key = String

	public typealias Value = String

	public var headers: [(String, String)] = []

	public init(dictionaryLiteral elements: (String, String)...) {
		self.headers = elements
	}

	public init(dictionary: [String: String]) {
		self.headers = dictionary.map({ ($0, $1) })
	}

	public init(_ elements: [(String, String)]) {
		self.headers = elements
	}

	public subscript(key: String) -> String? {
		for (k, v) in headers {
			if k == key {
				return v
			}
		}

		return nil
	}

	public func makeIterator() -> GHCHTTPHeadersIterator {
		GHCHTTPHeadersIterator(headers: self.headers)
	}
}

public struct GHCHTTPHeadersIterator: Sequence, IteratorProtocol {
	private var index: Int = 0
	private var headers: [(String, String)]

	public typealias Element = (key: String, value: String)

	init(headers: [(String, String)]) {
		self.headers = headers
	}

	public mutating func next() -> (key: String, value: String)? {
		guard !headers.isEmpty else { return nil }
		guard headers.count - 1 >= self.index else { return nil }
		let value = self.headers[self.index]
		self.index += 1
		return value
	}
}

public struct GHCHTTPResponse {
	public var headers: GHCHTTPHeaders
	public var body: [UInt8]?
	public var statusCode: Int

	public init(headers: GHCHTTPHeaders, statusCode: Int, body: [UInt8]? = nil) {
		self.headers = headers
		self.statusCode = statusCode
		self.body = body
	}
}

public enum GHCHTTPMethod: String {
	case GET
	case POST
	case PUT
	case PATCH
	case HEAD
	case DELETE
	case OPTIONS
}
