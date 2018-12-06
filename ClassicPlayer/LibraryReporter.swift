//
//  LibraryReporter.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 12/5/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import MediaPlayer


func reportLibrary() -> Data {
    let mediaAlbums = MPMediaQuery.albums()
    if mediaAlbums.collections == nil { return Data() }
    var report = [Dictionary<String,Any>]()
    for mediaAlbum in mediaAlbums.collections! {
        var tracks = [Dictionary<String,String>]()
        let albumItems = mediaAlbum.items
        for item in albumItems {
            tracks.append(["title": item.title ?? "", "composer": item.composer ?? ""])
        }
        let albumReport: Dictionary<String,Any> = ["albumTitle": albumItems[0].albumTitle ?? "",
                                                   "tracks": tracks]
        report.append(albumReport)
    }
    do {
        let data = try JSONSerialization.data(withJSONObject: report, options: .prettyPrinted)
        return data
    } catch {
       let error = error as NSError
       NSLog("error reporting media library: \(error), \(error.userInfo)")
    return Data()
    }
}
