//
//  PlaylistViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/27/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import MediaPlayer

//This VC uses SongTableViewCell

class PlaylistViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    weak var playlist: MPMediaPlaylist? {
        didSet {
            //Copy the playlist items to avoid obscure memory problem
            trackData = Array(playlist!.items)
        }
    }
    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var labelsStack: UIStackView!
    @IBOutlet weak var playlistName: UILabel!
    @IBOutlet weak var descriptionText: UILabel!
    @IBOutlet weak var trackTable: UITableView!
    var trackData: [MPMediaItem]?
    var playerViewController: AVPlayerViewController?
    var currentlyPlayingIndex = 0 //what's next in the player
    var firstIndexInPlayer = 0    //index of first movement in player
    var playerRate: Float = 0.0
    var contextString = "some stuff"

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        trackTable.delegate = self
        trackTable.dataSource = self
        trackTable.rowHeight = UITableViewAutomaticDimension
        trackTable.estimatedRowHeight = 64.0
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fontSizeChanged),
                                               name: .UIContentSizeCategoryDidChange,
                                               object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        playlistName?.text = playlist!.name
        descriptionText?.text = playlist!.descriptionText
        let id = playlist!.representativeItem?.albumPersistentID
        if let realID = id {
            //Someday we might elaborate the displayed artwork
            artwork?.image = AppDelegate.artworkFor(album: realID)
        }
       adjustStack()
        //Could be returning from
        if playerViewController?.player == nil {
            installPlayer()
            playerRate = 0.0 //On such a return the player is paused
            trackTable.reloadData()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("PieceVC.viewWillDisappear")
        playerViewController?.player = nil
    }
    
    @objc private func fontSizeChanged() {
        DispatchQueue.main.async {
            self.adjustStack()
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }
    
    private func adjustStack() {
        if UIApplication.shared.preferredContentSizeCategory > .extraExtraLarge {
            self.artAndLabelsStack.axis = .vertical
            self.artAndLabelsStack.alignment = .leading
        } else {
            self.artAndLabelsStack.axis = .horizontal
            self.artAndLabelsStack.alignment = .top
            //Content hugging priority lowered on text fields so they expand across the cell.
            self.artAndLabelsStack.distribution = .fill
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
            cell.artwork.isOpaque = false
            cell.artwork.alpha = 0.5
        } else {
            cell.indicator.stopAnimating()
            cell.indicator.animationImages = nil
            cell.indicator.image = appDelegate.audioNotCurrent
            cell.artwork.isOpaque = true
            cell.artwork.alpha = 1.0
        }
        let trackEntry = trackData![indexPath.row]
        let id = trackEntry.albumPersistentID
        cell.artwork.image = AppDelegate.artworkFor(album: id)
        cell.title.text = trackEntry.title
        cell.artist.text = trackEntry.artist
        cell.duration.text = AppDelegate.durationAsString(trackEntry.playbackDuration)
        //Priority lowered on artwork height to prevent unsatisfiable constraint.
        if UIApplication.shared.preferredContentSizeCategory > .extraExtraLarge {
            cell.artAndLabelsStack.axis = .vertical
            cell.artAndLabelsStack.alignment = .leading
        } else {
            cell.artAndLabelsStack.axis = .horizontal
            cell.artAndLabelsStack.alignment = .top
            //Content hugging priority lowered on text fields so they expand across the cell.
            cell.artAndLabelsStack.distribution = .fill
        }
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
            print("PlaylistVC.prepareForSegue")
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
            firstIndexInPlayer = 0 //start with all items
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
