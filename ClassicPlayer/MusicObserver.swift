//
//  MusicObserver.swift
//  ClassicalPlayer
//
//  Created by Frederick Kuhl on 2/2/19.
//  Copyright © 2019 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import MediaPlayer

protocol MusicObserverDelegate {
    func nowPlayingItemDidChange(to: MPMediaItem?)
    func playbackStateDidChange(to: MPMusicPlaybackState)
}


class MusicObserver {
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var observing = false
    var delegate: MusicObserverDelegate?
    
    func start(on delegate: MusicObserverDelegate) {
        assert(!observing, "MusicObserver already observing!")
        self.delegate = delegate
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(nowPlayingItemDidChange),
                                               name: .MPMusicPlayerControllerNowPlayingItemDidChange,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playbackStateDidChange),
                                               name: .MPMusicPlayerControllerPlaybackStateDidChange,
                                               object: nil)
        MPMusicPlayerController.applicationMusicPlayer.beginGeneratingPlaybackNotifications()
        observing = true
        NSLog("MusicObserver start observing")
    }

    func stop() {
        if observing {
            NSLog("MusicObserver stop observing")
            MPMusicPlayerController.applicationMusicPlayer.endGeneratingPlaybackNotifications()
            NotificationCenter.default.removeObserver(self)
            delegate = nil
            observing = false
        }
    }
    
    @objc
    func nowPlayingItemDidChange() {
        NSLog("MusicObserver now playing item index: \(MPMusicPlayerController.applicationMusicPlayer.indexOfNowPlayingItem)")
        delegate?.nowPlayingItemDidChange(to: MPMusicPlayerController.applicationMusicPlayer.nowPlayingItem)
    }
    
    @objc
    func playbackStateDidChange() {
        delegate?.playbackStateDidChange(to: MPMusicPlayerController.applicationMusicPlayer.playbackState)
    }
}
