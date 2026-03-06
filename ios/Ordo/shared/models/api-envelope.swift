import Foundation

struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T
    let meta: APIResponseMeta?
    let errors: [APIErrorPayload]
}

struct APIResponseMeta: Decodable {
    let total: Int?
    let offset: Int?
    let limit: Int?
    let timestamp: String?
}

struct APIErrorPayload: Decodable, Hashable {
    let code: String
    let message: String
    let field: String?
}
