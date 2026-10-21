import Foundation

// MARK: - The Metropolitan Museum of Art (The Met API) Service & Masterpieces

struct MetArtwork: Identifiable, Hashable {
    let id: Int
    let title: String
    let artist: String
    let imageUrl: String
    let year: String
}

final class TheMetService: ObservableObject {
    static let shared = TheMetService()

    /// Hand-curated, verified public domain masterworks from The Met Collection
    @Published var curatedArtworks: [MetArtwork] = [
        MetArtwork(
            id: 45434,
            title: "The Great Wave off Kanagawa",
            artist: "Katsushika Hokusai",
            imageUrl: "https://images.metmuseum.org/CRDImages/as/web-large/DP141042.jpg",
            year: "1831"
        ),
        MetArtwork(
            id: 436535,
            title: "Wheat Field with Cypresses",
            artist: "Vincent van Gogh",
            imageUrl: "https://images.metmuseum.org/CRDImages/ep/web-large/DP130999.jpg",
            year: "1889"
        ),
        MetArtwork(
            id: 437113,
            title: "Still Life with Apples and Primroses",
            artist: "Claude Monet",
            imageUrl: "https://images.metmuseum.org/CRDImages/ep/web-large/DT47.jpg",
            year: "1890"
        ),
        MetArtwork(
            id: 437881,
            title: "Young Woman with a Water Pitcher",
            artist: "Johannes Vermeer",
            imageUrl: "https://images.metmuseum.org/CRDImages/ep/web-large/DP353257.jpg",
            year: "ca. 1662"
        ),
        MetArtwork(
            id: 337497,
            title: "The Last Supper",
            artist: "Rembrandt van Rijn",
            imageUrl: "https://images.metmuseum.org/CRDImages/rl/web-large/DP287735.jpg",
            year: "1635"
        ),
        MetArtwork(
            id: 435876,
            title: "Madame Cézanne in a Red Dress",
            artist: "Paul Cézanne",
            imageUrl: "https://images.metmuseum.org/CRDImages/ep/web-large/DP320128.jpg",
            year: "1888"
        ),
        MetArtwork(
            id: 436819,
            title: "Mäda Primavesi",
            artist: "Gustav Klimt",
            imageUrl: "https://images.metmuseum.org/CRDImages/ep/web-large/DP243354.jpg",
            year: "1912"
        ),
        MetArtwork(
            id: 337625,
            title: "Young Girl Bathing",
            artist: "Pierre-Auguste Renoir",
            imageUrl: "https://images.metmuseum.org/CRDImages/rl/web-large/DP-17279-001.jpg",
            year: "1892"
        )
    ]

    /// Dynamic search against The Met Collection API v1.1
    func search(query: String) async -> [MetArtwork] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchUrl = URL(string: "https://collectionapi.metmuseum.org/public/collection/v1.1/search?hasImages=true&isHighlight=true&q=\(encoded)") else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: searchUrl)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ids = json["objectIDs"] as? [Int] else {
                return []
            }

            let topIds = Array(ids.prefix(6))
            var results: [MetArtwork] = []

            for objId in topIds {
                guard let objUrl = URL(string: "https://collectionapi.metmuseum.org/public/collection/v1/objects/\(objId)") else { continue }
                do {
                    let (objData, _) = try await URLSession.shared.data(from: objUrl)
                    if let objJson = try? JSONSerialization.jsonObject(with: objData) as? [String: Any],
                       let isPublicDomain = objJson["isPublicDomain"] as? Bool, isPublicDomain,
                       let title = objJson["title"] as? String,
                       let primaryImageSmall = objJson["primaryImageSmall"] as? String,
                       !primaryImageSmall.isEmpty {
                        let artist = (objJson["artistDisplayName"] as? String) ?? (objJson["culture"] as? String) ?? "The Met Collection"
                        let date = (objJson["objectDate"] as? String) ?? ""
                        results.append(MetArtwork(
                            id: objId,
                            title: title,
                            artist: artist,
                            imageUrl: primaryImageSmall,
                            year: date
                        ))
                    }
                } catch {
                    continue
                }
            }

            return results
        } catch {
            return []
        }
    }
}
