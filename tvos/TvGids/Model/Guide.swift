import Foundation

struct Guide: Codable, Sendable, Equatable {
    let version: Int
    let generatedAt: Date
    let channels: [Channel]

    static func decode(_ data: Data) throws -> Guide {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Guide.self, from: data)
    }
}

struct Channel: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let logo: String
    let app: String
    let scheme: String
    let programs: [Program]

    /// Zoekt het programma dat op `time` loopt (nu-lijn), of het eerstvolgende/laatste programma.
    func program(at time: Date) -> Program? {
        programs.first(where: { $0.isLive(at: time) })
            ?? programs.first(where: { $0.start >= time })
            ?? programs.last
    }
}

struct Program: Codable, Sendable, Equatable, Identifiable {
    let start: Date
    let end: Date
    let title: String
    let description: String?

    var id: Date { start }

    func isLive(at now: Date) -> Bool { start <= now && now < end }
}
