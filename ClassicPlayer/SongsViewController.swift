//
//  SongsViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/27/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import MediaPlayer

class SongsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var sortButton: UIBarButtonItem!
    @IBOutlet weak var trackTable: UITableView!
    var playerViewController: AVPlayerViewController?
    var trackData: [MPMediaItem]?
    var currentlyPlayingIndex = 0 //what's in the player
    var playerRate: Float = 0.0
    var contextString = "some stuff"
    
    private static var indexedSectionCount = 27  //A magic number; that's how many sections any UITableView index can have.
    private var sectionCount = 1
    private var sectionSize = 0
    private var sectionTitles: [String]?

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
            self.sortTracksBy(.title)
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
    }
    
    private func sortTracksBy(_ sort: SongSorts) {
        if let data = trackData {
            trackData = data.sorted{
                song1, song2 in
                return sort.sortField(from: song1) < sort.sortField(from: song2)
            }
        }
        computeSections(forSort: sort)
    }
    
    private func computeSections(forSort sort: SongSorts) {
        guard let unwrappedTracks = trackData else {
            return
        }
        if unwrappedTracks.count < SongsViewController.indexedSectionCount {
            sectionCount = 1
            sectionSize = unwrappedTracks.count
            sectionTitles = []
        } else {
            sectionCount = SongsViewController.indexedSectionCount
            sectionSize = unwrappedTracks.count / SongsViewController.indexedSectionCount
            sectionTitles = []
            for i in 0 ..< SongsViewController.indexedSectionCount {
                let track = unwrappedTracks[i * sectionSize]
                let indexString = sort.sortField(from: track)
                let indexEntry = indexString.prefix(2)
                sectionTitles?.append(String(indexEntry))
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
    
    // MARK: - Sort popover
    
    @IBAction func sortButtonTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let sortVC = storyboard.instantiateViewController(withIdentifier: "SongsSortController")
            as! SongSortViewController
        sortVC.songsViewController = self
        sortVC.preferredContentSize = CGSize(width: 200, height: 200)
        sortVC.modalPresentationStyle = .popover
        sortVC.popoverPresentationController?.barButtonItem = sortButton
        self.present(sortVC, animated: true) { }
    }
    
    func userDidChoose(sort: SongSorts) {
        self.dismiss(animated: true) { }
        sortTracksBy(sort)
        trackTable.reloadData()
    }

    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionCount
    }
    
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < SongsViewController.indexedSectionCount - 1 {
            return sectionSize
        } else {
            //that pesky last section
            return trackData!.count - SongsViewController.indexedSectionCount * sectionSize
        }
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sectionTitles
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Track", for: indexPath) as! SongTableViewCell
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if indexPath.section * sectionSize + indexPath.row == currentlyPlayingIndex {
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
        let trackEntry = trackData![indexPath.section * sectionSize + indexPath.row]
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
        currentlyPlayingIndex = indexPath.section * sectionSize + indexPath.row
        installPlayer()
        tableView.reloadData()
        playerViewController?.player?.play() //Tap on the table, it starts to play
    }

    // MARK: - Player management
    
    //The embed segue that places the AVPlayerViewController in the ContainerVC
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            //print("SongsVC.prepareForSegue")
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
