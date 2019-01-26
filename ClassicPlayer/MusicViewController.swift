//
//  MusicViewController.swift
//  ClassicalPlayer
//
//  Created by Frederick Kuhl on 1/24/19.
//  Copyright © 2019 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import MediaPlayer

fileprivate enum PlayerState {
    case playing
    case paused
}

class MusicViewController: UIViewController {
    @IBOutlet weak var trackLabel: UILabel!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var expendedTimeLabel: UILabel!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var remainingTimeLabel: UILabel!
    @IBOutlet weak var airplayButton: UIButton!
    var timer: Timer?
    var currentTrack: MPMediaItem?
    var trackDuration: TimeInterval?
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        trackLabel?.text = "nothing playing"
        setToPlay()
        airplayButton?.setTitle(" \u{2324}", for: .normal)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(nowPlayingItemDidChange),
                                               name: .MPMusicPlayerControllerNowPlayingItemDidChange,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playbackStateDidChange),
                                               name: .MPMusicPlayerControllerPlaybackStateDidChange,
                                               object: nil)
        MPMusicPlayerController.applicationMusicPlayer.beginGeneratingPlaybackNotifications()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in self.timerDidFire() }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        MPMusicPlayerController.applicationMusicPlayer.endGeneratingPlaybackNotifications()
        NotificationCenter.default.removeObserver(self)
    }

    
    @IBAction func playTouched(_ sender: Any) {
        switch (MPMusicPlayerController.applicationMusicPlayer.playbackState) {
        case .playing:
            MPMusicPlayerController.applicationMusicPlayer.pause()
        case .paused:
            MPMusicPlayerController.applicationMusicPlayer.play()
        default:
            NSLog("funny state")
        }
    }
    
    @objc
    func nowPlayingItemDidChange() {
        NSLog("now playing item index: \(MPMusicPlayerController.applicationMusicPlayer.indexOfNowPlayingItem)")
        currentTrack = MPMusicPlayerController.applicationMusicPlayer.nowPlayingItem
        trackDuration = currentTrack?.playbackDuration
        if let duration = trackDuration {
            timeSlider.maximumValue = Float(duration)
        }
        trackLabel?.text = labelForPlayer()
    }
    
    @objc
    func playbackStateDidChange() {
        let state: String
        switch (MPMusicPlayerController.applicationMusicPlayer.playbackState) {
        case .stopped:
            state = "stopped"
        case .playing:
            state = "playing"
            setToPause()
        case .paused:
            state = "paused"
            setToPlay()
        case .interrupted:
            state = "interrupted"
        case .seekingForward:
            state = "seeking forward"
        case .seekingBackward:
            state = "seeking backward"
        }
        NSLog("playback state: \(state)")
    }
    
    @objc
    func timerDidFire() {
        let trackElapsed = MPMusicPlayerController.applicationMusicPlayer.currentPlaybackTime
        NSLog("dur: \(trackDuration) elapsed: \(trackElapsed)")
        expendedTimeLabel.text = getTimeDisplayText(time: trackElapsed)
        if let duration = trackDuration {
            remainingTimeLabel.text = getTimeDisplayText(time: duration - trackElapsed)
        }
        timeSlider.value = Float(trackElapsed)
    }
    
    private func setToPlay() {
        playPauseButton?.setTitle("\u{25B6} ", for: .normal)
    }
    
    private func setToPause() {
        playPauseButton?.setTitle("\u{23F8} ", for: .normal)
    }
    
    private func getTimeDisplayText(time: TimeInterval) -> String {
        let timeMin = Int(time / 60)
        let timeSec = Int(time.truncatingRemainder(dividingBy: 60.0))
        let returnedText: String
        if timeSec < 10 {
            returnedText = "\(timeMin):0\(timeSec)"
        } else {
            returnedText = "\(timeMin):\(timeSec)"
        }
        return returnedText
    }

    private func labelForPlayer() -> String {
        if let composer = currentTrack?.composer {
            return composer + ": " + (currentTrack?.title ?? "")
        } else if let artist = currentTrack?.artist {
            return artist + ": " + (currentTrack?.title ?? "")
        } else {
            return currentTrack?.title ?? ""
        }
    }
}
