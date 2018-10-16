//
//  InfoViewController
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 3/3/2018.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit

protocol ProgressDelegate {
    func setProgress(progress: Float)
}

class InfoViewController: UIViewController, ProgressDelegate {
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @IBOutlet weak var buildAndVersionStack: UIStackView!
    @IBOutlet weak var version: UILabel!
    @IBOutlet weak var buildNumber: UILabel!
    @IBOutlet weak var libraryDate: UILabel!
    @IBOutlet weak var albums: UILabel!
    @IBOutlet weak var songs: UILabel!
    @IBOutlet weak var pieces: UILabel!
    @IBOutlet weak var movements: UILabel!
    @IBOutlet weak var activityBackground: UIView!
    @IBOutlet weak var progressBar: UIProgressView!
    
    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.activityBackground.isHidden = true
        self.progressBar.isHidden = true
        appDelegate.progressDelegate = nil
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateUI),
                                               name: .dataAvailable,
                                               object: nil)
       NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleClearingError),
                                               name: .clearingError,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInitializingError),
                                               name: .initializingError,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleLoadingError),
                                               name: .loadingError,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleSavingError),
                                               name: .savingError,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleStoreError),
                                               name: .storeError,
                                               object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
    }
    
    @objc
    private func updateUI() {
        //You might not think this needs to put a task on the main thread, but this gets call from
        //a number of places.
        DispatchQueue.main.async {
            self.activityBackground.isHidden = true
            self.progressBar.isHidden = true
            self.appDelegate.progressDelegate = nil
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            self.version?.text = "version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "")"
            self.buildNumber?.text = "build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "")"
            let dateString = appDelegate.mediaLibraryInfo?.lastModifiedDate?.description(with: Locale.current) ?? "[n.d.]"
            self.libraryDate?.text = "Media library date: \(dateString)"
            self.albums?.text = "Albums: \(appDelegate.mediaLibraryInfo?.albumCount ?? -1)"
            self.songs?.text = "Songs (tracks): \(appDelegate.mediaLibraryInfo?.songCount ?? -1)"
            self.pieces?.text = "Pieces: \(appDelegate.mediaLibraryInfo?.pieceCount ?? -1)"
            self.movements?.text = "Movements: \(appDelegate.mediaLibraryInfo?.movementCount ?? -1)"
        }
    }
    
    @IBAction func reloadLibrary(_ sender: UIButton) {
        DispatchQueue.main.async {
            //The actions are dispatched async to avoid the dread "_BSMachError"
            let alert = UIAlertController(title: "Reload iTunes Library?",
                                          message: "Load newest media?",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Load newest media", style: .destructive, handler: { _ in
                DispatchQueue.main.async {
                    self.activityBackground.isHidden = false
                    self.progressBar.isHidden = false
                    self.appDelegate.progressDelegate = self
                    self.progressBar.setProgress(0.0, animated: false)
                    self.view.setNeedsDisplay()
                    self.appDelegate.replaceAppLibraryWithMedia()
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                DispatchQueue.main.async {
                    self.updateUI()
                }
            }))
            self.present(alert, animated: true)
        }
    }
    
    @objc
    private func handleClearingError(notification: NSNotification) {
        let message = "\(String(describing: notification.userInfo))"
        alertAndExit(title: "Error Clearing Old Media", message: message)
    }
    
    @objc
    private func handleInitializingError(notification: NSNotification) {
        let message = "\(String(describing: notification.userInfo))"
        alertAndExit(title: "Error Initializing Audio", message: message)
    }
    
    @objc
    private func handleLoadingError(notification: NSNotification) {
        let message = "\(String(describing: notification.userInfo))"
        alertAndExit(title: "Error Loading Current Media", message: message)
    }
    
    @objc
    private func handleSavingError(notification: NSNotification) {
        let message = "\(String(describing: notification.userInfo))"
        alertAndExit(title: "Error Saving Current Media", message: message)
    }
    
    @objc
    private func handleStoreError(notification: NSNotification) {
        let message = "\(String(describing: notification.userInfo))"
        alertAndExit(title: "Error In Obtaining Local Storage", message: message)
    }
    
    @objc
    private func alertAndExit(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Exit App", style: .default, handler: { _ in
                exit(1)
            }))
            self.present(alert, animated: true)
        }
    }
    
    
    // MARK: - ProgressDelegate
    

    func setProgress(progress: Float) {
        DispatchQueue.main.async {
            self.progressBar.setProgress(progress, animated: true)
            self.view.setNeedsDisplay()
        }
    }
}

