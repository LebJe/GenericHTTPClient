// Copyright (c) 2022 Jeff Lebrun
//
//  Licensed under the MIT License.
//
//  The full text of the license can be found in the file named LICENSE.

import GenericHTTPClient

import Foundation

#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

public class URLSessionHTTPClient: GHCHTTPClient {
	private let urlSession: URLSession

	public init(session: URLSession = .shared) {
		self.urlSession = session
	}

	public func send(request: GHCHTTPRequest) async throws -> GHCHTTPResponse {
		try await withCheckedThrowingContinuation({ c in
			self.urlSession.dataTask(with: URLRequest(from: request), completionHandler: { data, urlResponse, error in
				if let error = error {
					c.resume(throwing: error)
				}
				let body: [UInt8]?

				if let d = data {
					body = Array(d)
				} else {
					body = nil
				}
				
				if let httpURLResponse = urlResponse as? HTTPURLResponse {
					c.resume(returning: GHCHTTPResponse(from: httpURLResponse, body: body))
				} else {
					c.resume(throwing: URLSessionClientError.couldNotCastToHTTPURLResponse)
				}

				
			}).resume()
		})
	}

	public func shutdown() {}
}

public enum URLSessionClientError: Error {
	case couldNotCastToHTTPURLResponse
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
