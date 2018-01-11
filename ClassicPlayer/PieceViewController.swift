//
//  PieceViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 12/26/17.
//  Copyright © 2017 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

class MovementTableViewCell: UITableViewCell {
    @IBOutlet weak var movementTitle: UILabel!
}

class PieceViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var composer: UILabel!
    @IBOutlet weak var pieceTitle: UILabel!
    @IBOutlet weak var artist: UILabel!
    @IBOutlet weak var movementTable: UITableView!
    var selectedPiece: Piece?
    var player: AVPlayer?
    var movements: NSOrderedSet?
    var contextString = "some stuff"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.movementTable.delegate = self
        self.movementTable.dataSource = self
        self.movementTable.rowHeight = UITableViewAutomaticDimension
        self.movementTable.estimatedRowHeight = 64.0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.title = selectedPiece?.title
        self.composer.text = selectedPiece?.composer
        self.pieceTitle.text = selectedPiece?.title
        self.artist.text = selectedPiece?.ensemble
        self.movements = selectedPiece?.movements
        let id = selectedPiece?.albumID
        if let realID = id {
            let returnedArtwork = AppDelegate.artworkFor(album: realID)
            if returnedArtwork != nil {
                self.artwork.image = returnedArtwork
                self.artwork.isOpaque = true
                self.artwork.alpha = 1.0
            } else {
                self.artwork.image = UIImage(named: "1706-music-note", in: nil, compatibleWith: nil)
                self.artwork.isOpaque = false
                self.artwork.alpha = 0.3
            }
        }
        //Priority lowered on artwork height to prevent unsatisfiable constraint.
        if UIApplication.shared.preferredContentSizeCategory > .extraExtraLarge {
            self.artAndLabelsStack.axis = .vertical
            self.artAndLabelsStack.alignment = .leading
        } else {
            self.artAndLabelsStack.axis = .horizontal
            self.artAndLabelsStack.alignment = .top
            //Content hugging priority lowered on text fields so they expand across the cell.
            self.artAndLabelsStack.distribution = .fill
        }
        if (selectedPiece?.movements) != nil && (selectedPiece?.movements)!.count > 0 {
            movementTable?.isHidden = false
        } else {
            movementTable?.isHidden = true
        }
    }
    
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return movements?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Movement", for: indexPath) as! MovementTableViewCell
        let movementEntry = movements![indexPath.row]
        cell.movementTitle?.text = (movementEntry as? Movement)?.title
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            let destination = segue.destination as! AVPlayerViewController
            if (selectedPiece?.movements) != nil && (selectedPiece?.movements)!.count > 0 {
                let movements = (selectedPiece?.movements)!.array
                let itemsToPlay: [AVPlayerItem] = movements.map {
                    return AVPlayerItem(url: (($0 as? Movement)?.trackURL)!)
                }
                destination.player = AVQueuePlayer(items: itemsToPlay)
                destination.player?.addObserver(self,
                                       forKeyPath: #keyPath(AVPlayer.currentItem),
                                       options: [.old, .new],
                                       context: &contextString)

            } else {
                destination.player = AVPlayer(url: (selectedPiece?.trackURL)!)
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        // Only handle observations for the playerItemContext
        guard context == &contextString else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }
        
        if keyPath == #keyPath(AVPlayer.currentItem) {
            // Get the status change from the change dictionary
            if let currentItem = change?[.newKey] as? AVPlayerItem {
                print("got a new currnetItem \(currentItem)")
            }
        }
    }

}
