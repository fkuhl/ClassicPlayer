//
//  CPMediaItem.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 10/4/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import Foundation
import MediaPlayer

/**
 This represents an attempt to gain a little efficiency by pulling all the needed
 values out of a MPMediaItem at once, using enumerateValues, as suggested by the doc.
 However, if any of the properties composer, genre, or artist are included, then
 enumerateValues crashes with a bad access for some MPMediaItem objects.
 Nobody has reported on this.
 So we conclude this isn't worth the 10% (max) improvement I'd get, so we're going to
 abandon this branch.
 */
fileprivate let propertySet: Set<String> = [
    MPMediaItemPropertyAlbumPersistentID,
    MPMediaItemPropertyAlbumTitle,
    MPMediaItemPropertyPersistentID,
    MPMediaItemPropertyTitle,
    ////MPMediaItemPropertyComposer,
    ////MPMediaItemPropertyGenre,
    MPMediaItemPropertyArtistPersistentID,
    ////MPMediaItemPropertyArtist,
    MPMediaItemPropertyPlaybackDuration,
    MPMediaItemPropertyAssetURL
]


fileprivate func debugCond(item:MPMediaItem) -> Bool {
    if let title = item.albumTitle {
        return title.range(of:"Documentary") != nil
    }
    return false
}

class CPMediaItem {
    var albumID = "" //encoded for CoreData
    var albumTitle = ""
    var persistentID = "" //encoded for CoreData
    var title = ""
    var composer = "<anon>"
    var genre = ""
    var artistID = ""
    var artist = ""
    var duration = "" //encoded
    var assetURL = URL(fileURLWithPath: "")
    
    init(from: MPMediaItem) {
        //print("composer: \(MPMediaItemPropertyComposer)")
        from.enumerateValues(forProperties: propertySet) {
            property, value, stop in
            switch property {
            case MPMediaItemPropertyAlbumPersistentID:
                if let pid = value as? MPMediaEntityPersistentID {
                    self.albumID = AppDelegate.encodeForCoreData(id: pid)
                }
            case MPMediaItemPropertyAlbumTitle:
                self.albumTitle = value as? String ?? ""
            case MPMediaItemPropertyPersistentID:
                if let pid = value as? MPMediaEntityPersistentID {
                    self.persistentID = AppDelegate.encodeForCoreData(id: pid)
                }
            case MPMediaItemPropertyTitle:
                self.title = value as? String ?? ""
            case MPMediaItemPropertyComposer:
                self.composer = value as? String ?? ""
            case MPMediaItemPropertyGenre:
                self.genre = value as? String ?? ""
            case MPMediaItemPropertyArtistPersistentID:
                if let pid = value as? MPMediaEntityPersistentID {
                    self.artistID = AppDelegate.encodeForCoreData(id: pid)
                }
            case MPMediaItemPropertyArtist:
                self.artist = value as? String ?? ""
            case MPMediaItemPropertyPlaybackDuration:
                if let interval = value as? TimeInterval {
                    self.duration = AppDelegate.durationAsString(interval)
                }
            case MPMediaItemPropertyAssetURL:
                self.assetURL = value as! URL
            default:
                return
            }
        }
    }
}
