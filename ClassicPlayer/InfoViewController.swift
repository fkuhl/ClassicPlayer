//
//  InfoViewController
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 3/3/2018.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import MediaPlayer
import MessageUI

protocol ProgressDelegate {
    func setProgress(progress: Float)
}

class InfoViewController: UIViewController, ProgressDelegate, MFMailComposeViewControllerDelegate, MusicObserverDelegate {
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    weak var musicViewController: MusicViewController?
    private var musicObserver = MusicObserver()

    @IBOutlet weak var appName: UILabel!
    @IBOutlet weak var buildVersion: UILabel!
    @IBOutlet weak var libraryDate: UILabel!
    @IBOutlet weak var albumCount: UILabel!
    @IBOutlet weak var trackCount: UILabel!
    @IBOutlet weak var pieceCount: UILabel!
    @IBOutlet weak var movementCount: UILabel!
    @IBOutlet weak var activityBackground: UIView!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var playerView: UIView!
    
    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.activityBackground.isHidden = true
        self.progressBar.isHidden = true
        appDelegate.progressDelegate = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleDataIsAvailable),
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
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleDataMissing),
                                               name: .dataMissing,
                                               object: nil)
        if musicPlayerPlaybackState() == .playing {
            playerView.isHidden = false
            musicViewController?.nowPlayingItemDidChange(to: MPMusicPlayerController.applicationMusicPlayer.nowPlayingItem)
            musicObserver.start(on: self)
        } else {
            playerView.isHidden = true
        }
        updateUI()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        musicObserver.stop()
    }

    /**
     Update UI to latest app database info.
     
     - Precondition: Called on main thread!
     */
    private func updateUI() {
        self.activityBackground.isHidden = true
        self.progressBar.isHidden = true
        self.appDelegate.progressDelegate = nil
        self.appName.text = "Classical\u{200B}Player" //zero-width space make name break properly on narrow screens!
        self.buildVersion?.text = "v \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? ""), " +
        "build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "")"
        let mediaLibraryInfo = appDelegate.mediaLibraryInfo
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .medium
        let dateString: String
        if let mediaDate = mediaLibraryInfo.date  {
            dateString = dateFormatter.string(from: mediaDate)
        } else {
            dateString = "[n.d.]"
        }
        self.libraryDate?.text = "Media lib date: \(dateString)"
        self.albumCount?.text = "\(mediaLibraryInfo.albums)"
        self.trackCount?.text = "\(mediaLibraryInfo.songs)"
        self.pieceCount?.text = "\(mediaLibraryInfo.pieces)"
        self.movementCount?.text = "\(mediaLibraryInfo.movements)"
        self.view.setNeedsDisplay()
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
    
    @IBAction func mailTitles(_ sender: UIButton) {
        if !MFMailComposeViewController.canSendMail() {
            let alert = UIAlertController(title: "Can't Send Mail",
                                          message: "Your phone isn't configured to send mail.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(alert, animated: true)
            return
        }
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = .withFullDate
        let mc = MFMailComposeViewController()
        mc.mailComposeDelegate = self
        mc.setSubject("titles not parsing correctly")
        mc.setMessageBody("<html><body>Please explain the problem you're seeing here!</body></html>", isHTML: true)
        mc.setToRecipients(["fkuhl@tyndalesoft.com"])
        mc.addAttachmentData(reportLibrary(),
                             mimeType: "application/json",
                             fileName: dateFormatter.string(from: Date()) + "-library-report.json")
        self.present(mc, animated: true, completion: nil)
    }
    
    func mailComposeController(_ controller:MFMailComposeViewController, didFinishWith result:MFMailComposeResult, error:Error?) {
        switch result {
        case .cancelled:
            print("Mail cancelled")
        case .saved:
            print("Mail saved")
        case .sent:
            print("Mail sent")
        case .failed:
            print("Mail sent failure: \(String(describing: error?.localizedDescription))")
        default:
            break
        }
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func enableArtwork(_ sender: UIButton) {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
    
    @objc
    private func handleDataIsAvailable() {
        //Notification arrives on a notification thread
        //Which, according to docs, is thread it was posted on.
        //Make no assumptions!
       DispatchQueue.main.async {
            self.updateUI()
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
    
    @objc
    private func  handleDataMissing(notification: NSNotification) {
        let title = "Missing Media"
        let message = "Some tracks do not have media. This probably can be fixed by synchronizing your device."
        DispatchQueue.main.async { //we're on a notification thread!
            self.updateUI() //clears the progress bar, before we show this alert
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            }))
            self.present(alert, animated: true)
        }
    }

    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            musicViewController = segue.destination as? MusicViewController
        }
    }

    // MARK: - ProgressDelegate

    func setProgress(progress: Float) {
        DispatchQueue.main.async {
            self.progressBar.setProgress(progress, animated: true)
            self.view.setNeedsDisplay()
        }
    }

    // MARK: - MusicObserverDelegate
    
    func nowPlayingItemDidChange(to item: MPMediaItem?) {
        DispatchQueue.main.async {
            NSLog("InfoVC now playing item is '\(item?.title ?? "<sine nomine>")'")
            self.musicViewController?.nowPlayingItemDidChange(to: item)
        }
    }
    
    func playbackStateDidChange(to state: MPMusicPlaybackState) {
        DispatchQueue.main.async {
            self.musicViewController?.playbackStateDidChange(to: state)
        }
    }
}

