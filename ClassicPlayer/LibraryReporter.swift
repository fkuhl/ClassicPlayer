//
//  LibraryReporter.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 12/5/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import Foundation
import MediaPlayer



/**
 Report contents of user's library for analysis by TyndaleSoft.
 Report takes the form of JSON encoding of the structures in ReportingStructures.
 
 - Returns: Data suitable for attachment to mail message.
 */

func reportLibrary() -> Data {
    let mediaAlbums = MPMediaQuery.albums()
    if mediaAlbums.collections == nil { return Data() }
    var albums = Array<AlbumReport>()
    for mediaAlbum in mediaAlbums.collections! {
        let albumItems = mediaAlbum.items
        var tracks = Array<TrackReport>()
        for item in albumItems {
            tracks.append(TrackReport(composer: item.composer ?? "", title: item.title ?? ""))
        }
        albums.append(AlbumReport(albumTitle: albumItems[0].albumTitle ?? "", tracks: tracks))
    }
    let library = LibraryReport(composers: composersInLibrary(), library: albums)
    do {
        let data = try JSONEncoder().encode(library)
        return data
    } catch {
       let error = error as NSError
       NSLog("error reporting media library: \(error), \(error.userInfo)")
    return Data()
    }
}
