//
//  RateObserver.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 11/22/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import MediaPlayer

protocol MusicPlayerObserver {
    func nowPlayingItemDidChange(to: MPMediaItem?)
    func playbackStateDidChange(to: MPMusicPlaybackState)
}


class RateObserver {
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var observing = false
    var observer: MusicPlayerObserver?
    
    func startObserving(on observer: MusicPlayerObserver) {
        assert(!observing, "Already observing!")
        self.observer = observer
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
        print("start rate observing")
    }
    
    func start(on controller: NSObject) {
        assert(!observing, "Already observing!")
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
        print("start rate observing")
    }

    func stop(on controller: NSObject) {
        if observing {
            MPMusicPlayerController.applicationMusicPlayer.endGeneratingPlaybackNotifications()
            NotificationCenter.default.removeObserver(self)
            observing = false
        }
    }
    
    @objc
    func nowPlayingItemDidChange() {
        NSLog("now playing item index: \(MPMusicPlayerController.applicationMusicPlayer.indexOfNowPlayingItem)")
        observer?.nowPlayingItemDidChange(to: MPMusicPlayerController.applicationMusicPlayer.nowPlayingItem)
    }
    
    @objc
    func playbackStateDidChange() {
        observer?.playbackStateDidChange(to: MPMusicPlayerController.applicationMusicPlayer.playbackState)
    }
}
