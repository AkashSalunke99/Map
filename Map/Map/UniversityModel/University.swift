import Foundation

struct UniversityData: Codable {
    let features: [University]
    static let url: URL = URL(string: "https://services2.arcgis.com/5I7u4SJE1vUr79JC/arcgis/rest/services/UniversityChapters_Public/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json")!
}

struct University: Codable {
    let attributes: Attribute
    let geometry: Geometry
}

struct Geometry: Codable {
    let x: Double
    let y: Double
}

struct Attribute: Codable {
    let University_Chapter: String
    let City: String
    let State: String
}

func fetchUniversityData() async -> [University] {
    do {
        let (data, _) = try await URLSession.shared.data(from: UniversityData.url)
        let decoder = JSONDecoder()
        let universityData = try decoder.decode(UniversityData.self, from: data)
        return universityData.features
    } catch {
        print("Error: \(error.localizedDescription)")
    }
    return []
}
