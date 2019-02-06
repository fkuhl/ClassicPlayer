//
//  MusicPlayer.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 10/29/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import MediaPlayer

enum MusicPlayerType {
    case single
    case queue
}

@objc class MusicPlayer: NSObject {
    private var _player = MPMusicPlayerController.applicationMusicPlayer //just so we don't have to write it out all the time
    private var _type = MusicPlayerType.single
    private var _setterID = ""
    //Note that the predecessor maintained the current player index. But MPMusicPlayerController does that.
    //controller's table index when player was set. Doesn't change as player runs
    private var _tableIndex = 0

    private var _queueSize = 0

    /**
     The case where one track is to be played, not from a table.
     */
    func setPlayer(item: MPMediaItem, setterID: String, paused: Bool) {
        NSLog("MusicPlayer.setPlayer from \(setterID), item: '\(item.title ?? "<sine nomine>")', paused: \(paused)")
        _type = .single
        _setterID = setterID
        _tableIndex = -1 //nonsensical
        _queueSize = 1
        var items = [MPMediaItem]()
        items.append(item)
        setQueueAndPrepareToPlay(items: items, paused: paused)
    }

    /**
    The case where several tracks are to be played from a table.
     */
    func setPlayer(items: [MPMediaItem], tableIndex: Int, setterID: String, paused: Bool) {
        NSLog("MusicPlayer.setPlayer from \(setterID), \(items.count) items, tableIndex: \(tableIndex), paused: \(paused)")
        _type = .queue
        _setterID = setterID
        _tableIndex = tableIndex
        _queueSize = items.count
        setQueueAndPrepareToPlay(items: items, paused: paused)
    }
    
    private func setQueueAndPrepareToPlay(items: [MPMediaItem], paused: Bool) {
        _player.pause()
        _player.shuffleMode = .off
        let dGroup = DispatchGroup()
        dGroup.enter()
        _player.setQueue(with: MPMediaItemCollection(items: items))
        _player.prepareToPlay() {
            (inError: Error?) in
            if let error = inError {
                NSLog("MusicPlayer prepareToPlay completion error: \(error), \(error.localizedDescription)")
            } else {
                if paused {
                    self._player.pause()
                } else {
                    self._player.play()
                }
            }
            dGroup.leave()
        }

    }
    
    var type: MusicPlayerType {
        get { return _type }
    }
    
    var setterID: String {
        get { return _setterID }
    }
    
    var currentTableIndex: Int {
        get {
            assert(_type == .queue, "MusicPlayer.currentTableIndex should not be accessed for single player")
            return _tableIndex + musicPlayerIndexOfNowPlayingItem()
        }
    }

}

func musicPlayerPlaybackState() -> MPMusicPlaybackState {
    return MPMusicPlayerController.applicationMusicPlayer.playbackState
}

func musicPlayerIndexOfNowPlayingItem() -> Int {
    return MPMusicPlayerController.applicationMusicPlayer.indexOfNowPlayingItem
}
