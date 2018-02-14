//
//  PlaylistsController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 12/26/17.
//  Copyright © 2017 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import MediaPlayer

class PlaylistTableViewCell: UITableViewCell {
    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var playlistTitle: UILabel!
}

class PlaylistsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private static let uninterestingPlaylists = [
        "Recently Added",
        "Recently Played",
        "Top 25 Most Played",
        "iTunes DJ",
        "Purchased"
    ]

    @IBOutlet weak var tableView: UITableView!
    var selectionValue: String?
    var selectionField: String?
    var displayTitle:   String?
    private var tableIsLoaded = false
    private var playlists: [MPMediaItemCollection]?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 72.0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !tableIsLoaded {
            updateUI()
            tableIsLoaded = true
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    private func updateUI() {
        let query = MPMediaQuery.playlists()
        for collection in query.collections! {
            if let playlist = collection as? MPMediaPlaylist {
                if !PlaylistsViewController.uninterestingPlaylists.contains(playlist.name!) && playlist.items.count > 0 {
                    print("playlist \(playlist.name ?? "[n.n.]")")
                    for item in playlist.items {
                        print("   item: \(item.title ?? "[n.t.]")")
                    }
                }
            }
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Playlist", for: indexPath) as! PieceTableViewCell
//        let pieceEntry = pieces![indexPath.row]
//        cell.pieceTitle?.text = pieceEntry.title
//        cell.pieceArtist?.text = pieceEntry.artist
//        let id = pieceEntry.albumID
//        if let realID = id {
//            cell.artwork.image = AppDelegate.artworkFor(album: realID)
//        }
//        //Priority lowered on artwork height to prevent unsatisfiable constraint.
//        if UIApplication.shared.preferredContentSizeCategory > .extraExtraLarge {
//            cell.artAndLabelsStack.axis = .vertical
//            cell.artAndLabelsStack.alignment = .leading
//        } else {
//            cell.artAndLabelsStack.axis = .horizontal
//            cell.artAndLabelsStack.alignment = .top
//            //Content hugging priority lowered on text fields so they expand across the cell.
//            cell.artAndLabelsStack.distribution = .fill
//        }
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PieceSelected" {
//            let secondViewController = segue.destination as! PieceViewController
//            if let selected = tableView?.indexPathForSelectedRow {
//                secondViewController.selectedPiece = pieces![selected.row]
//            }
        }
    }

}
