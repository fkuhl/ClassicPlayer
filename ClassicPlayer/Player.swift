//
//  Player.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 10/29/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import Foundation
import AVKit

enum PlayerType {
    case single
    case queue
}

@objc class Player: NSObject {
    //Must be var, not let, because is passed as observing context
    private var observingContext = Bundle.main.bundleIdentifier! + ".Player"
    private var _player = AVPlayer(playerItem: nil)
    private var _type = PlayerType.single
    private var _settingController = ""
    //controller's table index when player was set. Doesn't change as player runs
    private var _tableIndex = 0
    //index of tracks in current player
    @objc dynamic var currentPlayerIndex = 0 //for KVO to work, I can't make this read-only
    private var _queueSize = 0

    var player: AVPlayer {
        get { return _player }
    }

    func setPlayer(url: URL, settingController: String) -> AVPlayer? {
        _player.pause()
        _player = AVPlayer(url: url)
        _type = .single
        _settingController = settingController
        _tableIndex = -1 //nonsensical
        currentPlayerIndex = 0 //but this won't change
        _queueSize = 1
        return _player
    }

    func setPlayer(items: [AVPlayerItem], tableIndex: Int, settingController: String) -> AVPlayer? {
        //_type is .queue only by going through this code, which installs an observer
//        if _type == .queue {
//            _player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem))
//        }
        _player.pause()
        _player = AVQueuePlayer(items: items)
        _type = .queue
        _settingController = settingController
        _tableIndex = tableIndex
        currentPlayerIndex = 0
        _queueSize = items.count
        _player.addObserver(self,
                            forKeyPath: #keyPath(AVPlayer.currentItem),
                            options: [.old, .new],
                            context: &observingContext)
        return _player
    }
    
    var type: PlayerType {
        get { return _type }
    }
    
    var settingController: String {
        get { return _settingController }
    }
    
    var isActive: Bool {
        get {
            switch _type {
            case .single:
                return _player.rate > 0.0
            case .queue:
                //Actually, user might have paused during the last track
                return !(currentPlayerIndex == _queueSize - 1 && _player.rate <= 0.0)
            }
        }
    }
//
//    @objc dynamic var currentPlayerIndex: Int {
//        get {
//            assert(_type == .queue, "No current index except for queue player")
//            return _currentPlayerIndex
//        }
//    }
    
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
        if keyPath == #keyPath(AVPlayer.currentItem) {
            currentPlayerIndex += 1
            print("player index upd to \(currentPlayerIndex)")
            if currentPlayerIndex == _queueSize - 1 {
                //Just pause after last item, rather than searching for stuff.
                (object as? AVPlayer)?.actionAtItemEnd = .pause
            }
        }
    }

}
