//
//  IndexObserver.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 11/22/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

class IndexObserver {
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var observing = false
    
    func start(on controller: NSObject) {
        assert(!observing, "Already observing!")
        appDelegate.player.addObserver(controller,
                                                  forKeyPath: #keyPath(Player.currentPlayerIndex),
                                                  options: [.old, .new],
                                                  context: nil)
        observing = true
        print("start index observing")
    }
    
    func stop(on controller: NSObject) {
        if observing {
            appDelegate.player.removeObserver(controller, forKeyPath: #keyPath(Player.currentPlayerIndex))
            observing = false
        }
    }
}
