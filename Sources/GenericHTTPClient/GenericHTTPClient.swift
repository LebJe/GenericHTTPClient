// Copyright (c) 2022 Jeff Lebrun
//
//  Licensed under the MIT License.
//
//  The full text of the license can be found in the file named LICENSE.

import struct Foundation.URL
import Logging

public protocol GHCHTTPClient {
	associatedtype RequestError: Error

	func send(request: GHCHTTPRequest) async -> Result<GHCHTTPResponse, RequestError>
	func send(request: GHCHTTPRequest, logger: Logger) async -> Result<GHCHTTPResponse, RequestError>
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

	public var headers: [(key: String, value: String)] = []

	public init(dictionaryLiteral elements: (String, String)...) {
		self.headers = elements
	}

	public init(dictionary: [String: String]) {
		self.headers = dictionary.map({ ($0, $1) })
	}

	public init(_ elements: [(String, String)]) {
		self.headers = elements
	}

	public subscript(key: String, caseSensitive caseSensitive: Bool = true) -> String? {
		get {
			self.headers.first(where: {
				if caseSensitive {
					return $0.key == key
				} else {
					return $0.key.lowercased() == key.lowercased()
				}

			})?.value
		}
		set {
			if let index = self.headers.firstIndex(where: {
				if caseSensitive {
					return $0.key.lowercased() == key.lowercased()
				} else {
					return $0.key == key
				}
			}) {
				if let value = newValue {
					self.headers[index] = (key, value)
				} else {
					self.headers.remove(at: index)
				}
			} else {
				if let value = newValue {
					self.headers.append((key: key, value: value))
				}
			}
		}
	}

	public mutating func append(key: String, value: String) {
		self.headers.append((key, value))
	}

	public static func += (lhs: inout GHCHTTPHeaders, rhs: GHCHTTPHeaders) {
		lhs.headers.append(contentsOf: rhs.headers)
	}

	public static func + (lhs: GHCHTTPHeaders, rhs: GHCHTTPHeaders) -> GHCHTTPHeaders {
		GHCHTTPHeaders(lhs.headers + rhs.headers)
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
