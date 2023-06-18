// Copyright (c) 2022 Jeff Lebrun
//
//  Licensed under the MIT License.
//
//  The full text of the license can be found in the file named LICENSE.

import GenericHTTPClient
import Logging

import Foundation

#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

public class URLSessionHTTPClient: GHCHTTPClient {
	private let urlSession: URLSession

	public init(session: URLSession = .shared) {
		self.urlSession = session
	}

	public func send(request: GHCHTTPRequest) async -> Result<GHCHTTPResponse, GHCError> {
		await withCheckedContinuation({ c in
			self.urlSession.dataTask(with: URLRequest(from: request), completionHandler: { data, urlResponse, error in
				if let error = error {
					if let urlError = error as? URLError {
						c.resume(returning: .failure(urlError.error))
					} else {
						c.resume(returning: .failure(.other(error)))
					}

				} else {
					let body: [UInt8]?

					if let d = data {
						body = Array(d)
					} else {
						body = nil
					}

					if let httpURLResponse = urlResponse as? HTTPURLResponse {
						c.resume(returning: .success(GHCHTTPResponse(from: httpURLResponse, body: body)))
					} else {
						c.resume(returning: .failure(.castToGHCHTTPResponseFailed))
					}
				}
			}).resume()
		})
	}

	/// This function is the same as `send(request: GHCHTTPRequest)` because URLSession does not support swift-log.
	public func send(request: GHCHTTPRequest, logger: Logger) async -> Result<GHCHTTPResponse, GHCError> {
		await self.send(request: request)
	}

	public func shutdown() {}
}

extension URLRequest {
	init(from request: GHCHTTPRequest) {
		self.init(url: request.url)
		self.httpMethod = request.method.rawValue

		for (key, value) in request.headers {
			self.setValue(value, forHTTPHeaderField: key)
		}

		if let body = request.body {
			self.httpBody = Data(body)
		}
	}
}

extension GHCHTTPResponse {
	init(from response: HTTPURLResponse, body: [UInt8]? = nil) {
		let h = response.allHeaderFields.compactMap({ key, value -> (String, String)? in
			if let key = key as? String, let value = value as? String {
				return (key, value)
			} else {
				return nil
			}
		})

		self.init(headers: .init(h), statusCode: response.statusCode, body: body)
	}
}

extension URLError {
	var error: GHCError {
		switch self.code {
			case .callIsActive: return .network(.unavailable(.inPhoneCall))
			case .cannotConnectToHost: return .network(.cannotConnectToHost)
			case .cannotFindHost: return .network(.cannotResolveHostName)
			case .clientCertificateRejected: return .security(.clientCertificate(.rejected))
			case .clientCertificateRequired: return .security(.clientCertificate(.required))
			case .dnsLookupFailed: return .network(.dnsLookupFailed)
			case .httpTooManyRedirects: return .http(.tooManyRedirects)
			case .internationalRoamingOff: return .network(.unavailable(.internationalRoamingOff))
			case .networkConnectionLost: return .network(.unavailable(.interruptedConnection))
			case .notConnectedToInternet: return .network(.unavailable(.notConnected))
			case .redirectToNonExistentLocation: return .http(.missingRedirectURL)
			case .serverCertificateHasBadDate: return .security(.serverCertificate(.expired))
			case .serverCertificateHasUnknownRoot: return .security(.serverCertificate(.unknownRoot))
			case .serverCertificateNotYetValid: return .security(.serverCertificate(.invalid))
			case .serverCertificateUntrusted: return .security(.serverCertificate(.untrusted))
			case .secureConnectionFailed: return .security(.secureConnectionFailed)
			case .timedOut: return .http(.requestTimedOut)
			case .userAuthenticationRequired: return .security(.authenticationRequired)
			default: return .other(self)
		}
	}
}
