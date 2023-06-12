// Copyright (c) 2022 Jeff Lebrun
//
//  Licensed under the MIT License.
//
//  The full text of the license can be found in the file named LICENSE.

import AsyncHTTPClient
import GenericHTTPClient
import Logging
import NIOHTTP1

public enum AHCRequestError: Error {
	case clientError(HTTPClientError)
	case other(Error)
}

public class AHCHTTPClient: GHCHTTPClient {
	public typealias RequestError = AHCRequestError

	private let httpClient: HTTPClient

	public init(client: HTTPClient = .init(eventLoopGroupProvider: .createNew)) {
		self.httpClient = client
	}

	public func send(request: GHCHTTPRequest) async -> Result<GHCHTTPResponse, RequestError> {
		await self.sendInternal(request: request, logger: nil)
	}

	public func send(request: GHCHTTPRequest, logger: Logger) async -> Result<GHCHTTPResponse, RequestError> {
		await self.sendInternal(request: request, logger: logger)
	}

	private func sendInternal(request: GHCHTTPRequest, logger: Logger?) async -> Result<GHCHTTPResponse, RequestError> {
		do {
			let req = try HTTPClient.Request(from: request)

			if let logger = logger {
				return try .success(GHCHTTPResponse(from: await self.httpClient.execute(request: req, logger: logger).get()))
			} else {
				return try .success(GHCHTTPResponse(from: await self.httpClient.execute(request: req).get()))
			}
		} catch let error as HTTPClientError {
			return .failure(.clientError(error))
		} catch {
			return .failure(.other(error))
		}
	}

	public func shutdown() {
		try? self.httpClient.syncShutdown()
	}
}

extension HTTPClient.Request {
	init(from request: GHCHTTPRequest) throws {
		try self.init(
			url: request.url,
			method: .init(from: request.method),
			headers: HTTPHeaders(request.headers.map({ ($0, $1) }))
		)
		if let b = request.body {
			self.body = .bytes(b)
		}
	}
}

extension HTTPMethod {
	init(from method: GHCHTTPMethod) {
		switch method {
			case .GET: self = .GET
			case .PUT: self = .PUT
			case .HEAD: self = .HEAD
			case .POST: self = .POST
			case .DELETE: self = .DELETE
			case .OPTIONS: self = .OPTIONS
			default: self = .GET
		}
	}
}

extension GHCHTTPResponse {
	init(from response: HTTPClient.Response) {
		let body: [UInt8]?

		if let b = response.body {
			body = Array(buffer: b)
		} else {
			body = nil
		}

		self.init(headers: .init(response.headers.map({ ($0, $1) })), statusCode: Int(response.status.code), body: body)
	}
}
