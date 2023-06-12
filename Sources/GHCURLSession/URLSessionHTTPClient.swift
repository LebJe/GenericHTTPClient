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

public enum URLSessionError: Error {
	case couldNotCastToHTTPURLResponse
	case urlError(URLError)
	case other(Error)
}

public class URLSessionHTTPClient: GHCHTTPClient {
	public typealias RequestError = URLSessionError

	private let urlSession: URLSession

	public init(session: URLSession = .shared) {
		self.urlSession = session
	}

	public func send(request: GHCHTTPRequest) async -> Result<GHCHTTPResponse, RequestError> {
		await withCheckedContinuation({ c in
			self.urlSession.dataTask(with: URLRequest(from: request), completionHandler: { data, urlResponse, error in
				if let error = error {
					if let urlError = error as? URLError {
						c.resume(returning: .failure(.urlError(urlError)))
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
						c.resume(returning: .failure(.other(URLSessionError.couldNotCastToHTTPURLResponse)))
					}
				}
			}).resume()
		})
	}

	/// This function is the same as `send(request: GHCHTTPRequest)` because URLSession does not support swift-log.
	public func send(request: GHCHTTPRequest, logger: Logger) async -> Result<GHCHTTPResponse, RequestError> {
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
