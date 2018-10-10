//
//  CPMediaAlbum.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 10/4/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import Foundation
import MediaPlayer

struct CPMediaAlbum {
    let albumTitle: String
    let albumArtist: String
    let composer: String
    let genre: String
    let trackCount: Int32
    let albumID: String //encoded for CoreData
    let year: Int32
}

