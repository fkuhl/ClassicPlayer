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
    //Must be var, not let, because is passed as observing context
    private var observingContext = Bundle.main.bundleIdentifier! + ".MusicPlayer"
    private var _player = MPMusicPlayerController.applicationMusicPlayer //just so we don't have to write it out all the time
    private var _type = MusicPlayerType.single
    private var _setterID = ""
    private var _label = "not playing"
    //controller's table index when player was set. Doesn't change as player runs
    private var _tableIndex = 0
    //index of current tracks in player
    @objc dynamic var currentPlayerIndex = 0 //for KVO to work, I can't make this read-only
    private var _queueSize = 0

    //The case where one track is to be played, not from a table
    func setPlayer(item: MPMediaItem, setterID: String, label: String, paused: Bool) {
        var items = [MPMediaItem]()
        items.append(item)
        _player.pause()
        _player.setQueue(with: MPMediaItemCollection(items: items))
        _type = .single
        _setterID = setterID
        _label = label
        _tableIndex = -1 //nonsensical
        currentPlayerIndex = 0 //but this won't change
        _queueSize = 1
        _player.prepareToPlay() {
            (inError: Error?) in
            if let error = inError {
                NSLog("prepareToPlay completion error: \(error), \(error.localizedDescription)")
            } else {
                if paused {
                    self._player.pause()
                } else {
                    self._player.play()
                }
            }
        }
    }

    //The case where one track is to be played, but it's from a table
    func setPlayer(item: MPMediaItem, tableIndex: Int, setterID: String, label: String, paused: Bool) {
        var items = [MPMediaItem]()
        items.append(item)
        _player.pause()
        _player.setQueue(with: MPMediaItemCollection(items: items))
        _type = .single
        _setterID = setterID
        _label = label
        _tableIndex = tableIndex
        currentPlayerIndex = 0 //but this won't change
        _queueSize = 1
        _player.prepareToPlay() {
            (inError: Error?) in
            if let error = inError {
                NSLog("prepareToPlay completion error: \(error), \(error.localizedDescription)")
            } else {
                if paused {
                    self._player.pause()
                } else {
                    self._player.play()
                }
            }
        }
    }

    func setPlayer(items: [MPMediaItem], tableIndex: Int, setterID: String, label: String, paused: Bool) {
        //_type is .queue only by going through this code, which installs an observer
//        if _type == .queue {
//            _player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem))
//        }
        _player.pause()
        _player.setQueue(with: MPMediaItemCollection(items: items))
        _type = .queue
        _setterID = setterID
        _label = label
        _tableIndex = tableIndex
        currentPlayerIndex = 0
        _queueSize = items.count
        _player.addObserver(self,
                            forKeyPath: #keyPath(MPMusicPlayerController.indexOfNowPlayingItem),
                            options: [.old, .new],
                            context: &observingContext)
        _player.prepareToPlay() {
            (inError: Error?) in
            if let error = inError {
                NSLog("prepareToPlay completion error: \(error), \(error.localizedDescription)")
            } else {
                if paused {
                    self._player.pause()
                } else {
                    self._player.play()
                }
            }
        }
    }
    
    var type: MusicPlayerType {
        get { return _type }
    }
    
    var setterID: String {
        get { return _setterID }
    }
    
    var label: String {
        get { return _label }
    }
    
    var currentTableIndex: Int {
        get { return _tableIndex + currentPlayerIndex }
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard context == &observingContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }
        if keyPath == #keyPath(MPMusicPlayerController.indexOfNowPlayingItem) {
            currentPlayerIndex += 1
            print("player index upd to \(currentPlayerIndex)")
//            if currentPlayerIndex == _queueSize - 1 {
//                //Just pause after last item, rather than searching for stuff.
//                (object as? AVPlayer)?.actionAtItemEnd = .pause
//            }
        }
    }

}
