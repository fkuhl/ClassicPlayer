//
//  InfoViewController
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 3/3/2018.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import MessageUI

protocol ProgressDelegate {
    func setProgress(progress: Float)
}

class InfoViewController: UIViewController, ProgressDelegate, MFMailComposeViewControllerDelegate {
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    weak var playerViewController: AVPlayerViewController?
    weak var playerLabel: UILabel?

    @IBOutlet weak var buildVersion: UILabel!
    @IBOutlet weak var libraryDate: UILabel!
    @IBOutlet weak var albumCount: UILabel!
    @IBOutlet weak var trackCount: UILabel!
    @IBOutlet weak var pieceCount: UILabel!
    @IBOutlet weak var movementCount: UILabel!
    @IBOutlet weak var activityBackground: UIView!
    @IBOutlet weak var progressBar: UIProgressView!
    
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
                                               selector: #selector(dataDidArrive),
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
        playerViewController?.player = appDelegate.player.player
        playerLabel?.text = appDelegate.player.label
        updateUI()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    private func updateUI() {
        self.activityBackground.isHidden = true
        self.progressBar.isHidden = true
        self.appDelegate.progressDelegate = nil
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        self.buildVersion?.text = "v \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? ""), " +
        "build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "")"
        //            NSLog("updating info with \(appDelegate.mediaLibraryInfo?.albumCount ?? 0) albums and \(appDelegate.mediaLibraryInfo?.songCount ?? 0) songs at \(appDelegate.mediaLibraryInfo?.lastModifiedDate)" )
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .medium
        let dateString: String
        if let date = appDelegate.mediaLibraryInfo?.lastModifiedDate {
            dateString = dateFormatter.string(from: date)
        } else {
            dateString = "[n.d.]"
        }
        self.libraryDate?.text = "Media lib date: \(dateString)"
        self.albumCount?.text = "\(appDelegate.mediaLibraryInfo?.albumCount ?? 0)"
        self.trackCount?.text = "\(appDelegate.mediaLibraryInfo?.songCount ?? 0)"
        self.pieceCount?.text = "\(appDelegate.mediaLibraryInfo?.pieceCount ?? 0)"
        self.movementCount?.text = "\(appDelegate.mediaLibraryInfo?.movementCount ?? 0)"
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
    private func dataDidArrive() {
        //Notification arrives on a notification thread
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
        let message = "Some tracks do not have media. This probably can be fixed by synchronizing your device again."
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
            //print("InfoVC.prepareForSegue. playerVC: \(segue.destination)")
            playerViewController = segue.destination as? AVPlayerViewController
            //This installs the UILabel. After this, we just change the text.
            playerLabel = add(label: "not init", to: playerViewController!)
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

