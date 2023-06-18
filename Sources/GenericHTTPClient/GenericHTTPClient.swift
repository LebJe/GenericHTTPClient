// Copyright (c) 2022 Jeff Lebrun
//
//  Licensed under the MIT License.
//
//  The full text of the license can be found in the file named LICENSE.

import struct Foundation.URL
import Logging
import WebURL

public enum GHCError: Error {
	/// Network Errors.
	public enum Network {
		/// Failed to create TCP connection on time (From AsyncHTTPClient).
		case connectionTimeout

		/// The hostname could not be resolved.
		case cannotResolveHostName

		/// The host address could not be resolved using DNS.
		case cannotResolveHostAddress

		case cannotConnectToHost

		case connectionClosed

		case dnsLookupFailed

		/// Network is unavailable
		case unavailable(Reason)

		public enum Reason {
			/// The network is unavailable because the user has given your app permission to use cellular data. (Cellular-enabled
			/// Apple devices only)
			///
			/// - Reference: https://developer.apple.com/documentation/foundation/urlerror/networkunavailablereason/cellular
			case cellularDataRestricted

			/// A network connection failed because the user was in a phone call, while using a cellular network that does not
			/// support calling and internet connection simultaneously. (Cellular-enabled Apple devices only)
			///
			/// - Reference: https://developer.apple.com/documentation/foundation/urlerror/2293147-callisactive
			case inPhoneCall

			/// The user enabled Low Data Mode (Apple devices only)
			///
			/// - Reference: https://developer.apple.com/documentation/foundation/urlerror/networkunavailablereason/constrained
			case lowDataMode

			/// The system marked the network interface as expensive (Apple devices only)
			///
			/// - Reference: https://developer.apple.com/documentation/foundation/urlerror/networkunavailablereason/expensive
			case networkMarkedAsExpensive

			/// The attempted connection required activating a data context while roaming, but international roaming is disabled.
			/// (Cellular-enabled Apple devices only)
			///
			/// - Reference: https://developer.apple.com/documentation/foundation/urlerror/2292893-internationalroamingoff
			case internationalRoamingOff

			/// No internet connection.
			case notConnected

			/// Network is unreachable (from POSIX `ENETDOWN`)
			case unreachable

			/// The internet connection was lost during a request.
			case interruptedConnection
		}
	}

	public enum InvalidURL {
		/// URL scheme is not "http" or "https"
		case scheme(String)
		case unparsable
	}

	public enum Security {
		public enum ClientCertificate {
			case rejected
			case required
		}

		public enum ServerCertificate {
			case expired
			case invalid
			case unknownRoot
			case untrusted
		}

		public enum SSL {
			case loadPrivateKeyFailed
			case loadCertificateFailed
		}

		public enum TLS {
			case handshakeTimeOut
		}

		case authenticationRequired
		case secureConnectionFailed
		case clientCertificate(ClientCertificate)
		case serverCertificate(ServerCertificate)
		case ssl(SSL)
		case tls(TLS)
	}

	public enum HTTP {
		case tooManyRedirects
		case redirectCycle

		/// The server did not provide a redirect URL.
		case missingRedirectURL

		case requestTimedOut

		case invalidHeaders(Headers)

		public enum Headers {
			/// The "Content-Length" header is missing.
			case missingContentLength

			/// The size of the response body does not match the "Content-Length" header.
			case mismatchedContentLength

			/// Invalid characters in header names
			case invalidCharactersInNames([String])

			/// Invalid characters in header values
			case invalidCharactersInValues([String])
		}
	}

	public enum Proxy {
		case invalidResponse

		/// Unable to create a connection to the proxy within the time limit.
		case proxyConnectionTimeOut

		/// Proxy requires authentication
		case authenticationRequired
	}

	case network(Network)
	case http(HTTP)
	case invalidURL(InvalidURL)
	case proxy(Proxy)
	case security(Security)
	case other(Error)

	/// The client failed to convert its internal response structure to ``GHCHTTPResponse``.
	case castToGHCHTTPResponseFailed
}

public protocol GHCHTTPClient {
	func send(request: GHCHTTPRequest) async -> Result<GHCHTTPResponse, GHCError>
	func send(request: GHCHTTPRequest, logger: Logger) async -> Result<GHCHTTPResponse, GHCError>
	func shutdown()
}

public struct GHCHTTPRequest {
	public var url: URL
	public var method: GHCHTTPMethod
	public var headers: GHCHTTPHeaders = [:]
	public var body: [UInt8]?

	/// - Throws: ``GHCError``
	public init(url: URL, method: GHCHTTPMethod = .GET, headers: GHCHTTPHeaders = [:], body: Self.HTTPBody? = nil) throws {
		// Validate URL
		guard let webURL = WebURL(url.absoluteString) else {
			throw GHCError.invalidURL(.unparsable)
		}

		// Scheme
		guard webURL.scheme.contains("http") || webURL.scheme.contains("https") else {
			throw GHCError.invalidURL(.scheme(webURL.scheme))
		}

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
