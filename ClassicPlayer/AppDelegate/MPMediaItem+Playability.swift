//
//  MPMediaItem+Playability.swift
//  ClassicalPlayer
//
//  Created by Frederick Kuhl on 6/25/19.
//  Copyright © 2019 TyndaleSoft LLC. All rights reserved.
//

import Foundation
import MediaPlayer


// MARK: - Playability

enum PlayabilityCategory {
    case playable
    case protected
    case cloudItem
    case missingMedia
}

extension MPMediaItem {
    
    /**
     Determine playability of a track.
     We can play only .cloudItem or .playable.
     
     - Returns: playability category
     */
    func playabilityCategory() -> PlayabilityCategory {
        //If it's protected, we can't play it. Period.
        if hasProtectedAsset { return .protected }
        //If  unprotected but it's in the cloud, we can play (iTunes Match)
        if isCloudItem { return .cloudItem }
        //If it has a URL, we can play it regardless (we think)
        if assetURL != nil { return .playable }
        //If no URL, unprotected, and not cloud item, it's just missing
        return .missingMedia
    }
    
    func isPlayable() -> Bool {
        switch self.playabilityCategory() {
        case .playable:
            return true
        case .protected:
            return false
        case .cloudItem:
            return true
        case .missingMedia:
            return false
        }
    }
}
