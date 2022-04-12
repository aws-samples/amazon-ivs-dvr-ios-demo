//
//  StreamMetadata.swift
//  Live to VOD UIKit
//
//  Created by Uldis Zingis on 25/03/2022.
//

import Foundation

struct StreamMetadata: Decodable {
    var isChannelLive: Bool
    var livePlaybackUrl: String
    var playlistDuration: Int
    var masterKey: String
    var recordingStartedAt: String
}
