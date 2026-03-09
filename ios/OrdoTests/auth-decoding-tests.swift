import Foundation
import Testing
@testable import Ordo

@MainActor
struct AuthDecodingTests {
    @Test
    func loginEnvelopeToleratesFalseOptionalStrings() throws {
        let payload = """
        {
          "success": true,
          "data": {
            "accessToken": "access-token",
            "refreshToken": "refresh-token",
            "expiresIn": 900,
            "user": {
              "id": 2,
              "name": "Administrator",
              "email": false,
              "lang": "en_US",
              "tz": false,
              "avatarUrl": false
            }
          },
          "errors": [],
          "meta": {
            "timestamp": "2026-03-06T14:33:07.183Z"
          }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(APIEnvelope<TokenResponse>.self, from: payload)
        let response = try #require(envelope.data)

        #expect(envelope.success)
        #expect(response.user.email == nil)
        #expect(response.user.tz == nil)
        #expect(response.user.avatarUrl == nil)
    }

    @Test
    func principalEnvelopeToleratesFalseOptionalStrings() throws {
        let payload = """
        {
          "success": true,
          "data": {
            "uid": 2,
            "db": "odoo17",
            "odooUrl": "http://127.0.0.1:38421",
            "version": "17",
            "lang": "en_US",
            "groups": [1, 2],
            "name": "Administrator",
            "email": false,
            "tz": false
          },
          "errors": [],
          "meta": {
            "timestamp": "2026-03-06T14:33:07.183Z"
          }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(APIEnvelope<AuthenticatedPrincipal>.self, from: payload)
        let principal = try #require(envelope.data)

        #expect(envelope.success)
        #expect(principal.email == nil)
        #expect(principal.tz == nil)
    }
}