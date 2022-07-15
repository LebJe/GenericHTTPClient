# GenericHTTPClient

A generic interface for HTTP clients.

```swift
import GenericHTTPClient
import GHCAsyncHTTPClient
import GHCURLSession

let req = GHCHTTPRequest(
	url: URL(string: "https://example.com")!,
	method: .POST,
	headers: ["Content-Type": "application/json"],
	body: .string(
		"""
		{"string": "Hello, World"}
		"""
		)
)

let urlSessionClient = URLSessionHTTPClient()
let ahcClient = AHCHTTPClient()

let req = try await urlSessionClient.send(request: req)
let req2 = try await urlSessionClient.send(request: req)

extension String {
	/// Initialize `String` from an array of bytes.
	init(_ bytes: [UInt8]) {
		self = String(bytes.map({ Character(Unicode.Scalar($0)) }))
	}
}

print(req.body != nil ? String(req.body!) : "No body")
print(req2.body != nil ? String(req2.body!) : "No body")
```
