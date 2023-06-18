// Copyright (c) 2022 Jeff Lebrun
//
//  Licensed under the MIT License.
//
//  The full text of the license can be found in the file named LICENSE.

import AsyncHTTPClient
import GenericHTTPClient
import Logging
import NIOHTTP1
import NIOSSL

public class AHCHTTPClient: GHCHTTPClient {
	private let httpClient: HTTPClient

	public init(client: HTTPClient = .init(eventLoopGroupProvider: .createNew)) {
		self.httpClient = client
	}

	public func send(request: GHCHTTPRequest) async -> Result<GHCHTTPResponse, GHCError> {
		await self.sendInternal(request: request, logger: nil)
	}

	public func send(request: GHCHTTPRequest, logger: Logger) async -> Result<GHCHTTPResponse, GHCError> {
		await self.sendInternal(request: request, logger: logger)
	}

	private func sendInternal(request: GHCHTTPRequest, logger: Logger?) async -> Result<GHCHTTPResponse, GHCError> {
		do {
			let req = try HTTPClient.Request(from: request)

			if let logger = logger {
				return try .success(GHCHTTPResponse(from: await self.httpClient.execute(request: req, logger: logger).get()))
			} else {
				return try .success(GHCHTTPResponse(from: await self.httpClient.execute(request: req).get()))
			}
		} catch let error as HTTPClientError {
			return .failure(error.error)

		} catch let error as NIOSSLError {
			return .failure(error.error)
		} catch {
			#if canImport(Network)
				if let error = error as? HTTPClient.NWPOSIXError {
					switch error.errorCode {
						case .ENETDOWN: return .failure(.network(.unavailable(.notConnected)))
						case .ENETUNREACH: return .failure(.network(.unavailable(.unreachable)))
						default: return .failure(.other(error))
					}
				}
			#endif
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

extension NIOSSLError {
	var error: GHCError {
		switch self {
			// case .writeDuringTLSShutdown:

			// case .unableToAllocateBoringSSLObject:

			// case .noSuchFilesystemObject:

			case .failedToLoadCertificate: return .security(.ssl(.loadCertificateFailed))

			case .failedToLoadPrivateKey: return .security(.ssl(.loadPrivateKeyFailed))

			// case .handshakeFailed(_):

			// case .shutdownFailed(_):

			// case .cannotMatchULabel:

			// case .noCertificateToValidate:

			// case .unableToValidateCertificate:

			// case .cannotFindPeerIP:

			// case .readInInvalidTLSState:

			// case .uncleanShutdown:

			default: return .other(self)
		}
	}
}

extension HTTPClientError {
	var error: GHCError {
		switch self {
			// case .alreadyShutdown: return
			case .readTimeout: return .http(.requestTimedOut)
			case .remoteConnectionClosed: return .network(.connectionClosed)
			// case .cancelled: return
			// case .identityCodingIncorrectlyPresent: return
			case .invalidProxyResponse: return .proxy(.invalidResponse)
			case .contentLengthMissing: return .http(.invalidHeaders(.missingContentLength))
			case .proxyAuthenticationRequired: return .proxy(.authenticationRequired)
			case .redirectLimitReached: return .http(.tooManyRedirects)
			case .redirectCycleDetected: return .http(.redirectCycle)
			// case .traceRequestWithBody: return
			// case let .invalidHeaderFieldNames(names): return .http(.invalidHeaders(.invalidCharactersInNames(names)))
			// case .invalidHeaderFieldValues: return .http(.invalidHeaders(.invalidCharactersInValues(values)))
			case .bodyLengthMismatch: return .http(.invalidHeaders(.mismatchedContentLength))
			// case .writeAfterRequestSent: return
			case .connectTimeout: return .network(.connectionTimeout)
			case .httpProxyHandshakeTimeout: return .proxy(.proxyConnectionTimeOut)
			case .tlsHandshakeTimeout: return .security(.tls(.handshakeTimeOut))
			// case .serverOfferedUnsupportedApplicationProtocol: return
			// case .requestStreamCancelled: return
			// case .getConnectionFromPoolTimeout: return
			// case .deadlineExceeded: return
			default: return .other(self)
		}
	}
}
