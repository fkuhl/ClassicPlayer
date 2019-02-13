//
//  PlaylistViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/27/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import MediaPlayer

//This VC uses SongTableViewCell

class PlaylistViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MusicObserverDelegate {
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
    var musicViewController: MusicViewController?
    private var musicObserver = MusicObserver()
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

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
        let cell = tableView.dequeueReusableCell(withIdentifier: "Track", for: indexPath) as! SongTableViewCell
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
                cell.artwork.isOpaque = false
                cell.artwork.alpha = 0.5
            } else {
                cell.indicator.stopAnimating()
                cell.indicator.animationImages = nil
                cell.indicator.image = appDelegate.audioNotCurrent
                cell.artwork.isOpaque = true
                cell.artwork.alpha = 1.0
            }
        } else {
            //If it's not our player, show no audio indicators
            cell.indicator.stopAnimating()
            cell.indicator.animationImages = nil
            cell.indicator.image = appDelegate.audioNotCurrent
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
        setQueuePlayer(tableIndex: indexPath.row, paused: false)
        tableView.reloadData()
    }
    
    private func labelForPlayer(atIndex: Int) -> String {
        let composer = trackData![atIndex].composer
        let artist = trackData![atIndex].artist
        let title = trackData![atIndex].title
        if let uComposer = composer {
            return uComposer + ": " + (title ?? "")
        } else if let uArtist = artist {
            return uArtist + ": " + (title ?? "")
        } else {
            return title ?? ""
        }
    }
    
    private func mySetterID() -> String {
        return Bundle.main.bundleIdentifier! + ".PlaylistViewController" +
            ">" + AppDelegate.encodeForCoreData(id: playlist!.persistentID) 
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
    
    //The embed segue that places the AVPlayerViewController in the ContainerVC
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            musicViewController = segue.destination as? MusicViewController
        }
    }

    // MARK: - MusicObserverDelegate
    
    func nowPlayingItemDidChange(to item: MPMediaItem?) {
        DispatchQueue.main.async {
            //NSLog("PlaylistVC now playing item is '\(item?.title ?? "<sine nomine>")'")
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
