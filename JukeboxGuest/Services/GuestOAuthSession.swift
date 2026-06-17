import AuthenticationServices
import Foundation
import JukeboxCore

@MainActor
final class GuestOAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GuestOAuthSession()

    private var session: ASWebAuthenticationSession?

    func start(loginURL: URL) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: loginURL,
                callbackURLScheme: "jukeboxguest"
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let okValue = components.queryItems?.first(where: { $0.name == "ok" })?.value else {
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: okValue == "1")
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                continuation.resume(throwing: URLError(.cannotOpenFile))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow }
        return window ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

#if os(iOS)
import UIKit
#endif
