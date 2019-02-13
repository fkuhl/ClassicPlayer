//
//  AlbumTracksViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/27/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import MediaPlayer

class TrackTableViewCell: UITableViewCell {
    @IBOutlet weak var indicator: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var duration: UILabel!
}

class AlbumTracksViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MusicObserverDelegate {
    private var musicObserver = MusicObserver()
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    weak var album: Album? {
        didSet {
            loadTracks() //Must be performed before segue to install player!
        }
    }
    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var composer: UILabel!
    @IBOutlet weak var albumTitle: UILabel!
    @IBOutlet weak var artist: UILabel!
    @IBOutlet weak var trackTable: UITableView!
    @IBOutlet weak var year: UILabel!
    @IBOutlet weak var tracks: UILabel!
    weak var musicViewController: MusicViewController?
    var trackData: [MPMediaItem]?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        trackTable.delegate = self
        trackTable.dataSource = self
        trackTable.rowHeight = UITableView.automaticDimension
        trackTable.estimatedRowHeight = 64.0
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fontSizeChanged),
                                               name: UIContentSizeCategory.didChangeNotification,
                                               object: nil)
    }
    
    private func loadTracks() {
        let query = MPMediaQuery.songs()
        let idVal = AppDelegate.decodeIDFrom(coreDataRepresentation: (album?.albumID!)!)
        let predicate = MPMediaPropertyPredicate(value: idVal, forProperty: MPMediaItemPropertyAlbumPersistentID)
        query.filterPredicates = Set([ predicate ])
        trackData = []
        for collection in query.collections! {
            let possibleItem = collection.items.first
            if let item = possibleItem {
                if item.assetURL != nil { trackData?.append(item) } //iTunes LPs have nil URLs!!
            }
        }
        print("AlbumTracksVC loaded \(trackData?.count ?? -1) tracks")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("AlbumTracksVC will appear")
        let id = album?.albumID
        if let realID = id {
            self.artwork.image = AppDelegate.artworkFor(album: realID)
         }
        composer.text = album?.composer ?? "[]"
        albumTitle.text = album?.title
        artist.text = album?.artist
        let yearText: String
        if let year = album?.year {
            yearText = year > 0 ? "\(year)" : "[n.d.]"
        } else {
            yearText = "[n.d.]"
        }
        year?.text = "\(yearText) • \(album?.genre ?? "")"
        tracks?.text = "tracks: \(/*album?.trackCount ?? 0*/ trackData!.count)"
        //Priority lowered on artwork height to prevent unsatisfiable constraint.
        adjustStack()
        print("AlbumTracksVC.vWA '\(appDelegate.musicPlayer.setterID)' "
            + "player is playing: \(musicPlayerPlaybackState() == .playing) " +
            "current table index: \(appDelegate.musicPlayer.type == .queue ? String(appDelegate.musicPlayer.currentTableIndex) : "single") ")
        if musicPlayerPlaybackState() == .playing {
            musicViewController?.nowPlayingItemDidChange(to: MPMusicPlayerController.applicationMusicPlayer.nowPlayingItem)
            musicObserver.start(on: self)
            if appDelegate.musicPlayer.setterID == mySetterID() {
                scrollToCurrent()
            }
        } else {
            setQueuePlayer(tableIndex: 0, paused: true)
        }
        trackTable.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        musicObserver.stop()
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "Track", for: indexPath) as! TrackTableViewCell
        if appDelegate.musicPlayer.setterID == mySetterID() {
            if indexPath.row == appDelegate.musicPlayer.currentTableIndex {
                if musicPlayerPlaybackState() == .playing {
                    cell.indicator.image = nil
                    cell.indicator.animationImages = appDelegate.audioBarSet
                    cell.indicator.animationRepeatCount = 0 //like, forever
                    cell.indicator.animationDuration = 0.6  //sec
                    cell.indicator.startAnimating()
                } else {
                    cell.indicator.stopAnimating()
                    cell.indicator.animationImages = nil
                    cell.indicator.image = appDelegate.audioPaused
                }
            } else {
                cell.indicator.stopAnimating()
                cell.indicator.animationImages = nil
                cell.indicator.image = appDelegate.audioNotCurrent
            }
        } else {
            //If it's not our player, show no audio indicators
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
        setQueuePlayer(tableIndex: indexPath.row, paused: false)
        tableView.reloadData()
    }
    
    private func mySetterID() -> String {
        return Bundle.main.bundleIdentifier! + ".AlbumTracksViewController"
            + "." + (album?.albumID ?? "")
    }

    // MARK: - Player management

    private func setQueuePlayer(tableIndex: Int, paused: Bool) {
        musicObserver.stop()
        let partialList = Array(trackData![tableIndex...])
        appDelegate.musicPlayer.setPlayer(items: partialList,
                                          tableIndex: tableIndex,
                                          setterID: mySetterID(),
                                          paused: paused)
        musicViewController?.setInitialItem(item: partialList[0])
        musicObserver.start(on: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            musicViewController = segue.destination as? MusicViewController
        }
    }

    // MARK: - MusicObserverDelegate
    
    func nowPlayingItemDidChange(to item: MPMediaItem?) {
        DispatchQueue.main.async {
            //NSLog("AlbumTracksVC now playing item is '\(item?.title ?? "<sine nomine>")'")
            self.musicViewController?.nowPlayingItemDidChange(to: item)
            self.trackTable.reloadData()
            self.scrollToCurrent()
        }
    }
    
    private func scrollToCurrent() {
        //As of iOS 11, the scroll seems to need a little delay.
        let deadlineTime = DispatchTime.now() + .milliseconds(100)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            if let visibleIndexPaths = self.trackTable.indexPathsForVisibleRows {
                let currentPath = IndexPath(indexes: [0, self.appDelegate.musicPlayer.currentTableIndex])
                if !visibleIndexPaths.contains(currentPath) {
                    self.trackTable.scrollToRow(at: currentPath, at: .bottom, animated: true)
                }
            }
        }
    }
    
    func playbackStateDidChange(to state: MPMusicPlaybackState) {
        DispatchQueue.main.async {
            self.trackTable.reloadData()
            self.musicViewController?.playbackStateDidChange(to: state)
        }
    }

}
