//
//  ReportingStructures.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 12/13/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import Foundation

/**
 Structures that constitute (after JSON encoding) a report of a user's library.
 This file is used by ClassicPrinter on the receiving end, so incorporates
 no libraries not available under macOS.
 */

struct TrackReport: Codable {
    var composer: String
    var title: String
}

struct AlbumReport: Codable {
    var albumTitle: String
    var tracks: [TrackReport]
}

struct LibraryReport: Codable {
    var composers: [String]
    var library: [AlbumReport]
}
