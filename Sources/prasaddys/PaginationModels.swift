import Foundation

// MARK: - Pagination Metadata
public struct PaginationMeta: Codable, Sendable {
    public let currentPage: Int
    public let totalPages: Int
    public let totalRecords: Int
    public let limit: Int

    public init(currentPage: Int, totalPages: Int, totalRecords: Int, limit: Int) {
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.totalRecords = totalRecords
        self.limit = limit
    }
}

// MARK: - Generic Paginated Envelope
public struct PaginatedEnvelope<T: Codable & Sendable>: Codable, Sendable {
    public let items: [T]
    public let pagination: PaginationMeta

    private struct DynamicCodingKeys: CodingKey {
        public var stringValue: String
        public var intValue: Int? { nil }

        public init?(stringValue: String) {
            self.stringValue = stringValue
        }

        public init?(intValue: Int) {
            return nil
        }
    }

    public init(items: [T], pagination: PaginationMeta) {
        self.items = items
        self.pagination = pagination
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        guard let itemsKey = container.allKeys.first(where: { $0.stringValue.lowercased() != "pagination" }) else {
            throw DecodingError.keyNotFound(
                DynamicCodingKeys(stringValue: "items")!,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected items key not found"
                )
            )
        }

        self.items = try container.decode([T].self, forKey: itemsKey)
        self.pagination = try container.decode(PaginationMeta.self, forKey: DynamicCodingKeys(stringValue: "pagination")!)
    }

    public func encode(to encoder: Encoder) throws {
        _ = encoder.container(keyedBy: DynamicCodingKeys.self)

        // Encoding with dynamic key named "items" is not supported in generic way
        // so you might want to override this or customize if you encode back.
        // For now, we won't support encoding (throw error)

        throw EncodingError.invalidValue(
            self,
            EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Encoding not implemented for PaginatedEnvelope"
            )
        )
    }
}
