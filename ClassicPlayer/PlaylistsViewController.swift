//
//  PlaylistsController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 12/26/17.
//  Copyright © 2017 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import MediaPlayer

class PlaylistTableViewCell: UITableViewCell {
    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var playlistName: UILabel!
}

class PlaylistsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MusicObserverDelegate {
    
    private static let uninterestingPlaylists = [
        //"Recently Added",
        //"Recently Played",
        //"Top 25 Most Played",
        "iTunes DJ",
        "Purchased"
    ]

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var playerViewHeight: NSLayoutConstraint!
    var selectionValue: String?
    var selectionField: String?
    var displayTitle:   String?
    private var playlists: [MPMediaPlaylist]?
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    weak var musicViewController: MusicViewController?
    private var musicObserver = MusicObserver()


    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 72.0
    }
    
    private func loadLists() {
        playlists = []
        let query = MPMediaQuery.playlists()
        for collection in query.collections! {
            if let playlist = collection as? MPMediaPlaylist {
                if !PlaylistsViewController.uninterestingPlaylists.contains(playlist.name!) && playlist.items.count > 0 {
                    playlists?.append(playlist)
                }
                let lists = playlists!
                playlists = lists.sorted {
                    list1, list2 in
                    let name1 = list1.name ?? ""
                    let name2 = list2.name ?? ""
                    return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if musicPlayerPlaybackState() == .playing {
            playerViewHeight.constant = MusicPlayer.height
            musicViewController?.nowPlayingItemDidChange(to: MPMusicPlayerController.applicationMusicPlayer.nowPlayingItem)
            musicObserver.start(on: self)
        } else {
            playerViewHeight.constant = 0.0
        }
        loadLists()
        tableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        musicObserver.stop()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - UITableViewDataSource

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Playlist", for: indexPath) as! PlaylistTableViewCell
        let playlistEntry = playlists![indexPath.row]
        cell.playlistName.text = playlistEntry.name
        let id = playlistEntry.representativeItem?.albumPersistentID
        if let realID = id {
            //Someday we might elaborate the displayed artwork
            cell.artwork.image = AppDelegate.artworkFor(album: realID)
        }
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            musicViewController = segue.destination as? MusicViewController
        }
        if segue.identifier == "PlaylistSelected" {
            let secondViewController = segue.destination as! PlaylistViewController
            if let selected = tableView?.indexPathForSelectedRow {
                secondViewController.playlist = playlists![selected.row]
            }
        }
    }

    // MARK: - MusicObserverDelegate
    
    func nowPlayingItemDidChange(to item: MPMediaItem?) {
        DispatchQueue.main.async {
            NSLog("PlaylistsVC now playing item is '\(item?.title ?? "<sine nomine>")'")
            self.musicViewController?.nowPlayingItemDidChange(to: item)
        }
    }
    
    func playbackStateDidChange(to state: MPMusicPlaybackState) {
        DispatchQueue.main.async {
            self.musicViewController?.playbackStateDidChange(to: state)
        }
    }
}
