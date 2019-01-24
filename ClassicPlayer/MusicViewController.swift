//
//  MusicViewController.swift
//  ClassicalPlayer
//
//  Created by Frederick Kuhl on 1/24/19.
//  Copyright © 2019 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import MediaPlayer

class MusicViewController: UIViewController {
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var pauseButton: UIButton!
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    
    @IBAction func playTouched(_ sender: Any) {
        MPMusicPlayerController.applicationMusicPlayer.play()
    }
    
    @IBAction func pauseTouched(_ sender: Any) {
        MPMusicPlayerController.applicationMusicPlayer.pause()
    }
}
