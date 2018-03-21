//
//  InfoViewController
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 3/3/2018.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit

class InfoViewController: UIViewController {
    @IBOutlet weak var buildAndVersionStack: UIStackView!
    @IBOutlet weak var version: UILabel!
    @IBOutlet weak var buildNumber: UILabel!
    @IBOutlet weak var libraryDate: UILabel!
    @IBOutlet weak var albums: UILabel!
    @IBOutlet weak var tracks: UILabel!
    @IBOutlet weak var pieces: UILabel!
    @IBOutlet weak var movements: UILabel!
    
    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        version?.text = "version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "")"
        buildNumber?.text = "build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "")"
        let dateString = appDelegate.mediaLibraryInfo?.lastModifiedDate?.description(with: Locale.current) ?? "[n.d.]"
        libraryDate?.text = "Media library date: \(dateString)"
        albums?.text = "Albums: \(appDelegate.mediaLibraryInfo?.albumCount ?? -1)"
        tracks?.text = "Tracks: \(appDelegate.mediaLibraryInfo?.trackCount ?? -1)"
        pieces?.text = "Pieces: \(appDelegate.mediaLibraryInfo?.pieceCount ?? -1)"
        movements?.text = "Movements: \(appDelegate.mediaLibraryInfo?.movementCount ?? -1)"
    }
}

