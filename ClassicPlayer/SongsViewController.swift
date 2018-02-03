//
//  AlbumTracksViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/27/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import MediaPlayer

class SongTableViewCell: UITableViewCell {
    @IBOutlet weak var indicator: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var duration: UILabel!
}

class SongsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var trackTable: UITableView!
    var playerViewController: AVPlayerViewController?
    var trackData: [MPMediaItem]?
    var currentlyPlayingIndex = 0 //what's next in the player
    var firstIndexInPlayer = 0    //index of first movement in player
    var playerRate: Float = 0.0
    var contextString = "some stuff"

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Songs"
        trackTable.delegate = self
        trackTable.dataSource = self
        trackTable.rowHeight = UITableViewAutomaticDimension
        trackTable.estimatedRowHeight = 64.0
        loadTracks()
    }
    
    private func loadTracks() {
        let query = MPMediaQuery.songs()
        trackData = []
        for collection in query.collections! {
            let possibleItem = collection.items.first
            if let item = possibleItem {
                if item.assetURL != nil { trackData?.append(item) } //iTunes LPs have nil URLs!!
            }
        }
        print("songs retrieved \(query.collections!.count)")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //Could be returning from
        if playerViewController?.player == nil {
            installPlayer()
            playerRate = 0.0 //On such a return the player is paused
            trackTable.reloadData()
        }
    }

    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return trackData?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Track", for: indexPath) as! SongTableViewCell
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if indexPath.row == currentlyPlayingIndex {
            if playerRate < 0.5 {
                cell.indicator.stopAnimating()
                cell.indicator.animationImages = nil
                cell.indicator.image = appDelegate.audioPaused
            } else {
                cell.indicator.image = nil
                cell.indicator.animationImages = appDelegate.audioBarSet
                cell.indicator.animationRepeatCount = 0 //like, forever
                cell.indicator.animationDuration = 0.6  //sec
                cell.indicator.startAnimating()
            }
        } else {
            cell.indicator.stopAnimating()
            cell.indicator.animationImages = nil
            cell.indicator.image = appDelegate.audioNotCurrent
        }
        let trackEntry = trackData![indexPath.row]
        cell.title.text = trackEntry.title
        cell.duration.text = AppDelegate.durationAsString(trackEntry.playbackDuration)
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        firstIndexInPlayer = indexPath.row
        currentlyPlayingIndex = indexPath.row
        let partialList = trackData![indexPath.row...]
        let playerItems: [AVPlayerItem] = partialList.map {
            item in
            return AVPlayerItem(url: item.assetURL!)
        }
        setQueuePlayer(items: playerItems)
        if currentlyPlayingIndex == trackData!.count - 1 {
            //Just pause after last item, rather than searching for stuff.
            playerViewController?.player?.actionAtItemEnd = .pause
        }
        tableView.reloadData()
        playerViewController?.player?.play() //Tap on the table, it starts to play
    }

    // MARK: - Player management

    private func setQueuePlayer(items: [AVPlayerItem]) {
        playerViewController?.player = AVQueuePlayer(items: items)
        playerViewController?.player?.addObserver(self,
                                                  forKeyPath: #keyPath(AVPlayer.currentItem),
                                                  options: [.old, .new],
                                                  context: &contextString)
        playerViewController?.player?.addObserver(self,
                                                  forKeyPath: #keyPath(AVPlayer.rate),
                                                  options: [.old, .new],
                                                  context: &contextString)
        if items.count == 1 {
            playerViewController?.player?.actionAtItemEnd = .pause
        }
    }
    
    //The embed segue that places the AVPlayerViewController in the ContainerVC
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            print("SongsVC.prepareForSegue")
            self.playerViewController = segue.destination as? AVPlayerViewController
            installPlayer()
        }
    }

    private func installPlayer() {
        if trackData != nil && trackData!.count > 0 {
            let playerItems: [AVPlayerItem] = trackData!.map {
                item in
                return AVPlayerItem(url: item.assetURL!)
            }
            firstIndexInPlayer = 0 //start with all movements
            currentlyPlayingIndex = 0
            setQueuePlayer(items: playerItems)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard context == &contextString else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }
        if keyPath == #keyPath(AVPlayer.currentItem) {
            if let currentItem = change?[.newKey] as? AVPlayerItem {
                currentlyPlayingIndex += 1
                print("new currentItem, index \(currentlyPlayingIndex) \(currentItem)")
                if currentlyPlayingIndex == trackData!.count - 1 {
                    //Just pause after last item, rather than searching for stuff.
                    (object as? AVPlayer)?.actionAtItemEnd = .pause
                }
                DispatchQueue.main.async { self.trackTable.reloadData() }
                //As of iOS 11, the scroll seems to need a little delay.
                let deadlineTime = DispatchTime.now() + .milliseconds(100)
                DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                    if let visibleIndexPaths = self.trackTable.indexPathsForVisibleRows {
                        let currentPath = IndexPath(indexes: [0, self.currentlyPlayingIndex])
                        if !visibleIndexPaths.contains(currentPath) {
                            self.trackTable.scrollToRow(at: currentPath, at: .bottom, animated: true)
                        }
                    }
                }
            }
        }
        if keyPath == #keyPath(AVPlayer.rate) {
            if let rate = change?[.newKey] as? NSNumber {
                playerRate = rate.floatValue
                DispatchQueue.main.async { self.trackTable.reloadData() }
            }
        }
    }

}
