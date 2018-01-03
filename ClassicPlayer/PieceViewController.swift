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
    @IBOutlet weak var label: UILabel!
    var selectedPiece: Piece?
    var player: AVPlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        player = AVPlayer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        label?.text = selectedPiece?.title
    }
}
