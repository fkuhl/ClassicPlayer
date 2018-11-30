//
//  Player.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 10/29/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
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
    private var _setterID = ""
    private var _label = "not playing"
    //controller's table index when player was set. Doesn't change as player runs
    private var _tableIndex = 0
    //index of current tracks in player
    @objc dynamic var currentPlayerIndex = 0 //for KVO to work, I can't make this read-only
    private var _queueSize = 0

    var player: AVPlayer {
        get { return _player }
    }

    //The case where one track is to be played, not from a table
    func setPlayer(url: URL, setterID: String, label: String) -> AVPlayer? {
        _player.pause()
        _player = AVPlayer(url: url)
        _type = .single
        _setterID = setterID
        _label = label
        _tableIndex = -1 //nonsensical
        currentPlayerIndex = 0 //but this won't change
        _queueSize = 1
        return _player
    }

    //The case where one track is to be played, but it's from a table
    func setPlayer(url: URL, tableIndex: Int, setterID: String, label: String) -> AVPlayer? {
        _player.pause()
        _player = AVPlayer(url: url)
        _type = .single
        _setterID = setterID
        _label = label
        _tableIndex = tableIndex
        currentPlayerIndex = 0 //but this won't change
        _queueSize = 1
        return _player
    }

    func setPlayer(items: [AVPlayerItem], tableIndex: Int, setterID: String, label: String) -> AVPlayer? {
        //_type is .queue only by going through this code, which installs an observer
//        if _type == .queue {
//            _player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem))
//        }
        _player.pause()
        _player = AVQueuePlayer(items: items)
        _type = .queue
        _setterID = setterID
        _label = label
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
    
    var setterID: String {
        get { return _setterID }
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

func add(label: String, to playerVC: AVPlayerViewController) -> UILabel {
    let uiLabel = UILabel()
    uiLabel.translatesAutoresizingMaskIntoConstraints = false
    uiLabel.text = label
    uiLabel.textAlignment = .center
    //uiLabel.adjustsFontSizeToFitWidth = true
    uiLabel.textColor = UIColor.gray
    uiLabel.backgroundColor = UIColor.black
    let playerVCV = playerVC.contentOverlayView
    playerVCV?.addSubview(uiLabel)
    let playerVCVLayout = playerVCV?.safeAreaLayoutGuide
    uiLabel.heightAnchor.constraint(equalToConstant: 30.0).isActive = true
    uiLabel.topAnchor.constraint(equalTo: playerVCVLayout!.topAnchor).isActive = true
    uiLabel.leadingAnchor.constraint(equalTo: playerVCVLayout!.leadingAnchor, constant: 60.0).isActive = true
    uiLabel.trailingAnchor.constraint(equalTo: playerVCVLayout!.trailingAnchor, constant: -60.0).isActive = true
    return uiLabel
}
