import Foundation
import FlyingFox

struct ArtworkProxyHandler: HTTPHandler {
    private static let allowedHosts = [
        "mzstatic.com",
        "googleusercontent.com",
        "ggpht.com",
        "ytimg.com",
        "scdn.co",
        "spotifycdn.com",
        "i.scdn.co",
        "is1-ssl.mzstatic.com",
        "is2-ssl.mzstatic.com",
        "is3-ssl.mzstatic.com",
        "is4-ssl.mzstatic.com",
        "is5-ssl.mzstatic.com",
    ]

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        if let raw = request.query.first(where: { $0.name == "url" })?.value,
           let normalized = ArtworkURLNormalizer.normalize(raw),
           let url = URL(string: normalized),
           isAllowedHost(url) {
            return await fetchRemoteImage(url: url)
        }

        if let serviceRaw = request.query.first(where: { $0.name == "service" })?.value,
           let musicID = request.query.first(where: { $0.name == "music_id" })?.value,
           let service = MusicService(rawValue: serviceRaw) {
            let title = request.query.first(where: { $0.name == "title" })?.value
            let artist = request.query.first(where: { $0.name == "artist" })?.value
            let resolverRequest = ArtworkResolverRegistry.Request(
                service: service,
                musicID: musicID,
                title: title,
                artist: artist
            )
            if let data = await ArtworkResolverRegistry.shared.resolveImageData(resolverRequest), !data.isEmpty {
                return imageResponse(data: data, contentType: "image/jpeg")
            }
        }

        return HTTPResponse(statusCode: .notFound, body: Data("artwork unavailable".utf8))
    }

    private func isAllowedHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return Self.allowedHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }

    private func fetchRemoteImage(url: URL) async -> HTTPResponse {
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 8
        urlRequest.setValue("image/*", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), !data.isEmpty else {
                return HTTPResponse(statusCode: .badGateway)
            }
            let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? "image/jpeg"
            return imageResponse(data: data, contentType: contentType)
        } catch {
            return HTTPResponse(statusCode: .badGateway, body: Data("artwork fetch failed".utf8))
        }
    }

    private func imageResponse(data: Data, contentType: String) -> HTTPResponse {
        var headers = HTTPHeaders()
        headers[.contentType] = contentType
        headers.addValue("public, max-age=86400", for: HTTPHeader("Cache-Control"))
        return HTTPResponse(statusCode: .ok, headers: headers, body: data)
    }
}
