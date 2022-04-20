//
//  Networking.swift
//  Live to VOD UIKit
//
//  Created by Uldis Zingis on 25/03/2022.
//

import Foundation
import Combine

class Networking {
    static let shared = Networking()
    private let decoder = JSONDecoder()
    private var cancellables = Set<AnyCancellable>()
    private var lastFethedStreamMetadata: StreamMetadata?

    var liveUrl: String {
        return lastFethedStreamMetadata?.livePlaybackUrl ?? ""
    }
    var vodUrl: String {
        return "\(Constants.distributionDomainName)/\(lastFethedStreamMetadata?.masterKey ?? "")"
    }

    func getStreamMetadata(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(Constants.distributionDomainName)/\(Constants.streamMetadataFileName)") else {
            print("❌ Server url not set")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared
            .dataTaskPublisher(for: request)
            .map(\.data)
            .sink { completion in
                switch completion {
                    case .finished:
                        print("Rooms list fetching complete")
                    case .failure(let error):
                        print("❌ Error received: \(error.localizedDescription)")
                }
            } receiveValue: { [weak self] data in
                do {
                    let metadata = try self?.decoder.decode(StreamMetadata.self, from: data)
                    self?.lastFethedStreamMetadata = metadata
                    DispatchQueue.main.async {
                        completion(true)
                    }
                } catch {
                    print("❌ Could not decode metadata: \(error.localizedDescription), raw reason: \(String(data: data, encoding: .utf8) ?? "\(data)")")
                    completion(false)
                }
            }
            .store(in: &cancellables)
    }
}
