//
//  MusicViewController.swift
//  ClassicalPlayer
//
//  Created by Frederick Kuhl on 1/24/19.
//  Copyright © 2019 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import AVKit
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
    var seekGoal: Float?
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        trackLabel?.text = "nothing playing"
        setButtonToDisplayPlay()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in self.timerDidFire() }
        playPauseButton?.isEnabled = currentTrack != nil
        timeSlider?.isEnabled = currentTrack != nil
        airplayButton?.isEnabled = currentTrack != nil
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
    }
    
    func setInitialItem(item: MPMediaItem) {
        currentTrack = item
        resetForNewItem()
    }

    
    @IBAction func playTouched(_ sender: Any) {
        switch (musicPlayerPlaybackState()) {
        case .playing:
            MPMusicPlayerController.applicationMusicPlayer.pause()
        case .paused, .stopped:
            MPMusicPlayerController.applicationMusicPlayer.play()
        default:
            NSLog("MusicVC funny state")
        }
    }
    
    /**
     Slider has "continuous events" checked in IB.
     */
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        //NSLog("MusicVC sliding to \(timeSlider.value)")
        MPMusicPlayerController.applicationMusicPlayer.currentPlaybackTime = TimeInterval(timeSlider.value)
        displayCurrentPlaybackTime()
    }
    
    @IBAction func airplayTouched(_ sender: UIButton) {
        let title = "Coming Soon!"
        let message = "Airplay coming soon! (I hope)"
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            }))
            self.present(alert, animated: true)
    }
    
    func nowPlayingItemDidChange(to newItem: MPMediaItem?) {
        //NSLog("MusicVC now playing item is '\(newItem?.title ?? "<sine nomine>")'")
        currentTrack = newItem
        resetForNewItem()
    }
    
    private func resetForNewItem() {
        trackDuration = currentTrack?.playbackDuration
        if let duration = trackDuration {
            //NSLog("MusicVC setting slider max to \(Float(duration))")
            timeSlider.maximumValue = Float(duration)
        }
        trackLabel?.text = labelForPlayer()
        displayCurrentPlaybackTime()
        if musicPlayerPlaybackState() == .playing {
            setButtonToDisplayPause()
        } else {
            setButtonToDisplayPlay()
        }
    }

    func playbackStateDidChange(to: MPMusicPlaybackState) {
        let state: String
        switch (musicPlayerPlaybackState()) {
        case .stopped:
            state = "stopped"
        case .playing:
            state = "playing"
            setButtonToDisplayPause()
        case .paused:
            state = "paused"
            setButtonToDisplayPlay()
        case .interrupted:
            state = "interrupted"
        case .seekingForward:
            state = "seeking forward"
        case .seekingBackward:
            state = "seeking backward"
        @unknown default:
            fatalError("MusicVC.playbackStateDidChange MPMusicPlaybackState unknown enum value")
        }
        NSLog("MusicVC playback state changed to: \(state)")
    }
    
    @objc
    func timerDidFire() {
        let trackElapsed = MPMusicPlayerController.applicationMusicPlayer.currentPlaybackTime
        switch (musicPlayerPlaybackState()) {
        case .stopped:
            break
        case .playing:
            displayCurrentPlaybackTime()
        case .paused:
            break
        case .interrupted:
            NSLog("MusicVC player interrupted at \(trackElapsed)")
        case .seekingForward:
            displayCurrentPlaybackTime()
            if Float(trackElapsed) >= seekGoal! { MPMusicPlayerController.applicationMusicPlayer.endSeeking() }
        case .seekingBackward:
            displayCurrentPlaybackTime()
            if Float(trackElapsed) <= seekGoal! { MPMusicPlayerController.applicationMusicPlayer.endSeeking() }
        @unknown default:
            fatalError("MusicVC.timerDidFire MPMusicPlaybackState unknown enum value")
        }
    }
    
    private func displayCurrentPlaybackTime() {
        let trackElapsed = MPMusicPlayerController.applicationMusicPlayer.currentPlaybackTime
        //NSLog("dur: \(trackDuration) elapsed: \(trackElapsed)")
        expendedTimeLabel.text = getTimeDisplayText(time: trackElapsed)
        if let duration = trackDuration {
            remainingTimeLabel.text = getTimeDisplayText(time: duration - trackElapsed)
        }
        timeSlider.setValue(Float(trackElapsed), animated: true)
    }
    
    private func setButtonToDisplayPlay() {
        //playPauseButton?.setTitle("\u{25B6} ", for: .normal)
        playPauseButton?.setImage(UIImage(named: "play"), for: .normal)
    }
    
    private func setButtonToDisplayPause() {
        //playPauseButton?.setTitle("\u{23F8} ", for: .normal)
        playPauseButton?.setImage(UIImage(named: "pause"), for: .normal)
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        NSLog("MusicVC segue \(segue.identifier ?? "unidentified")")
        if segue.identifier == "RoutePicker" {
//            if let controller = segue.destination as? RoutePickerViewController {
//            }
        }
    }
}
