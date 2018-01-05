//
//  PieceViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 12/26/17.
//  Copyright © 2017 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import AVFoundation

class PieceViewController: UIViewController {
    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var composer: UILabel!
    @IBOutlet weak var pieceTitle: UILabel!
    @IBOutlet weak var artist: UILabel!
    var selectedPiece: Piece?
    var player: AVPlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        player = AVPlayer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.composer.text = selectedPiece?.composer
        self.pieceTitle.text = selectedPiece?.title
        self.artist.text = selectedPiece?.ensemble
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
    }
}
