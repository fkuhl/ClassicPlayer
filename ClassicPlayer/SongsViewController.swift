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
    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var indicator: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var artist: UILabel!
    @IBOutlet weak var year: UILabel!
    @IBOutlet weak var duration: UILabel!
}

class SongsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var trackTable: UITableView!
    var playerViewController: AVPlayerViewController?
    var trackData: [MPMediaItem]?
    var currentlyPlayingIndex = 0 //what's in the player
    var playerRate: Float = 0.0
    var contextString = "some stuff"

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Songs"
        trackTable.delegate = self
        trackTable.dataSource = self
        trackTable.rowHeight = UITableViewAutomaticDimension
        trackTable.estimatedRowHeight = 128.0
        DispatchQueue.global(qos: .userInitiated).async {
            self.loadTracks()
            DispatchQueue.main.async {
                self.trackTable.reloadData()
            }
        }
    }
    
    /* It turns out it's vastly faster to load songs by album, than
       to do a MPMediaQuery.songs(). Even with a sort by title afterward.
    */
    private func loadTracks() {
        let query = MPMediaQuery.albums()
        trackData = []
        for collection in query.collections! {
            for item in collection.items {
                if item.assetURL != nil { trackData?.append(item) } //iTunes LPs have nil URLs!!
            }
        }
        print("songs retrieved \(trackData?.count ?? 0)")
        //Sort by song title
        if let data = trackData {
            trackData = data.sorted{
                song1, song2 in
                if let t1 = song1.title {
                    if let t2 = song2.title {
                        return t1 < t2
                    } else {
                        return false
                    }
                } else {
                    return true
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("SongsVC.vWA")
        //Could be returning from
        if playerViewController?.player == nil {
            //currentlyPlayingIndex = 0
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
        currentlyPlayingIndex = indexPath.row
        installPlayer()
        tableView.reloadData()
        playerViewController?.player?.play() //Tap on the table, it starts to play
    }

    // MARK: - Player management
    
    //The embed segue that places the AVPlayerViewController in the ContainerVC
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            print("SongsVC.prepareForSegue")
            self.playerViewController = segue.destination as? AVPlayerViewController
        }
    }

    private func installPlayer() {
        if trackData != nil && trackData!.count > 0 {
            playerViewController?.player = AVPlayer(url: (trackData?[currentlyPlayingIndex].assetURL)!)
            playerViewController?.player?.addObserver(self,
                                                      forKeyPath: #keyPath(AVPlayer.rate),
                                                      options: [.old, .new],
                                                      context: &contextString)
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
        if keyPath == #keyPath(AVPlayer.rate) {
            if let rate = change?[.newKey] as? NSNumber {
                playerRate = rate.floatValue
                DispatchQueue.main.async { self.trackTable.reloadData() }
            }
        }
    }

}
