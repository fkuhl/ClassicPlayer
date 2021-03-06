//
//  ComposersViewController
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 9/2/17.
//  Copyright © 2017 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import CoreData
import MediaPlayer

class ComposersViewController: UIViewController, NSFetchedResultsControllerDelegate, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, ProgressDelegate, MusicObserverDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityBackground: UIView!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var playerViewHeight: NSLayoutConstraint!
    let searchController = UISearchController(searchResultsController: nil)
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private let mediaLibrary = ClassicalMediaLibrary.sharedInstance
    private var musicObserver = MusicObserver()
    private var tableIsLoaded = false
    private var libraryAccessChecked = false
    private var artworkEnabledChecked = false
    
    private static let indexedSectionCount = 27  //A magic number; that's how many sections any UITableView index can have.
    private var composerObjects: [NSDictionary]?
    private var sectionCount = 1
    private var sectionSize = 0
    private var sectionTitles: [String]?
    weak var musicViewController: MusicViewController?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.activityBackground.isHidden = true
        self.progressBar.isHidden = true
        mediaLibrary.progressDelegate = nil
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Composers"
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //print("ComposersVC.viewWillAppear: \(self) player: \(mediaLibrary.player)")
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleDataIsAvailable),
                                               name: .dataAvailable,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleLibraryChanged),
                                               name: .libraryChanged,
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
            playerViewHeight.constant = MusicPlayer.height
            musicViewController?.nowPlayingItemDidChange(to: MPMusicPlayerController.applicationMusicPlayer.nowPlayingItem)
            musicObserver.start(on: self)
        } else {
            playerViewHeight.constant = 0.0
        }
        if !tableIsLoaded {
            updateUI()
            tableIsLoaded = true
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //checkArtworkEnabled()       In build 21, artwork is always enabled!
        checkMediaLibraryAccess()
    }
    
    private func checkArtworkEnabled() {
        if artworkEnabledChecked { return }
        artworkEnabledChecked = true
        if UserDefaults.standard.bool(forKey: AppDelegate.displayArtworkKey) { return }
        DispatchQueue.main.async {
            //The action is dispatched async to avoid the dread "_BSMachError"
            let alert = UIAlertController(title: "Enable Artwork?",
                                          message: "Would you like to enable the display of artwork?",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Enable in Settings", style: .default, handler: { _ in
                DispatchQueue.main.async {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
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
    
    private func checkMediaLibraryAccess() {
        if libraryAccessChecked { return }
        //Check authorization to access media library
        MPMediaLibrary.requestAuthorization { status in
            switch status {
            case .notDetermined:
            break //not clear how you'd ever get here, as the request will determine authorization
            case .authorized:
                //Avoid the assumption that we know what thread requestAuthorization returns on
                DispatchQueue.main.async {
                    self.mediaLibrary.checkLibraryChanged(context: self.mediaLibrary.mainThreadContext)
                }
            case .restricted:
                self.alertAndGoToSettings(message: "Media library access restricted by corporate or parental controls")
            case .denied:
                self.alertAndGoToSettings(message:
                    "Please give ClassicalPlayer access to your Media Library and restart it.")
            @unknown default:  //added on migration to Swift 5
                fatalError("ComposersVC.vDidA unknown library access enum")
            }
            self.libraryAccessChecked = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        musicObserver.stop()
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

    /**
     Update UI to latest app database info.
     
     - Precondition: Called on main thread!
     */
    private func updateUI() {
        let request = NSFetchRequest<NSDictionary>()
        request.entity = NSEntityDescription.entity(forEntityName: "Piece", in: mediaLibrary.mainThreadContext)
        request.resultType = .dictionaryResultType
        request.returnsDistinctResults = true
        request.propertiesToFetch = [ "composer" ]
        if isFiltering() {
            request.predicate = NSPredicate(format: "composer CONTAINS[cd] %@", searchController.searchBar.text!)
        } else {
            request.predicate = NSPredicate(format: "composer <> %@", "") //No blank composers!
        }
        request.sortDescriptors = [ NSSortDescriptor(key: "composer",
                                                     ascending: true,
                                                     selector: #selector(NSString.localizedCaseInsensitiveCompare)) ]
        do {
            self.composerObjects = try mediaLibrary.mainThreadContext.fetch(request)
            NSLog("ComposersVC: fetch returned \(self.composerObjects!.count) composer things")
            self.computeSections()
            self.tableView.reloadData()
            self.activityBackground.isHidden = true
            self.progressBar.isHidden = true
        }
        catch {
            let error = error as NSError
            let message = "\(String(describing: error.userInfo))"
            NSLog("error retrieving composers: \(error), \(error.userInfo)")
            alertAndExit(title: "Error Retrieving Composers", message: message)
        }
    }
    
    @objc
    private func handleLibraryChanged() {
        DispatchQueue.main.async {
            //The actions are dispatched async to avoid the dread "_BSMachError"
            let alert = UIAlertController(title: "iTunes Library Changed",
                                          message: "Load newest media?",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Load newest media", style: .destructive, handler: { _ in
                DispatchQueue.main.async {
                    self.activityBackground.isHidden = false
                    self.progressBar.isHidden = false
                    self.mediaLibrary.progressDelegate = self
                    self.progressBar.setProgress(0.0, animated: false)
                    self.view.setNeedsDisplay()
                    NSLog("started animation")
                    self.mediaLibrary.replaceAppLibraryWithMedia()
                }
            }))
            alert.addAction(UIAlertAction(title: "Skip the load for now", style: .cancel, handler: { _ in
                DispatchQueue.main.async {
                    self.mediaLibrary.retrieveMediaLibraryInfo(from: self.mediaLibrary.mainThreadContext)
                    self.updateUI()
                }
            }))
            self.present(alert, animated: true)
        }
    }
    
    @objc
    private func alertAndGoToSettings(message: String) {
        DispatchQueue.main.async {
            //The action is dispatched async to avoid the dread "_BSMachError"
            let alert = UIAlertController(title: "ClassicalPlayer Requests Access", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Go to Settings", style: .default, handler: { _ in
                DispatchQueue.main.async {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                              options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]),
                                              completionHandler: nil)
                }
            }))
            self.present(alert, animated: true)
            //...aaand somehow the app is relaunching after this...
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
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                DispatchQueue.main.async {
                    self.updateUI()
                }
            }))
            self.present(alert, animated: true)
        }
    }

    private func computeSections() {
        guard let unwrappedComposerObjects = composerObjects else {
            sectionCount = 1
            sectionSize = 0
            return
        }
        if presentAsOneSection() {
            sectionCount = 1
            sectionSize = composerObjects!.count
            sectionTitles = []
            return
        }
        sectionCount = ComposersViewController.indexedSectionCount
        sectionSize = composerObjects!.count / ComposersViewController.indexedSectionCount
        sectionTitles = []
        for i in 0 ..< ComposersViewController.indexedSectionCount {
            let dict = unwrappedComposerObjects[i * sectionSize]
            let composer = dict["composer"] as? String
            let title = composer?.prefix(2)
            //print("title \(i) is \(title ?? "nada")")
            sectionTitles?.append(String(title!))
        }
    }
    
    private func presentAsOneSection() -> Bool {
        if composerObjects == nil { return true }
        return composerObjects!.count < ComposersViewController.indexedSectionCount * 3
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionCount
    }
    
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let unwrappedComposerObjects = composerObjects else {
            return 1
        }
        if sectionCount == 1 {
            return unwrappedComposerObjects.count
        }
        if section < ComposersViewController.indexedSectionCount - 1 {
            return sectionSize
        } else {
            //that pesky last section
            return unwrappedComposerObjects.count - (sectionCount - 1) * sectionSize
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Composer", for: indexPath)
        if let unwrappedComposerObjects = composerObjects {
            let composerEntry = unwrappedComposerObjects[indexPath.section * sectionSize + indexPath.row]  //works even if 1 section
            let reportedComposer = composerEntry["composer"] as? String
            cell.textLabel?.text = (reportedComposer == "") ? "[no composer listed]" : reportedComposer
        } else {
            cell.textLabel?.text = "[no composers]"
        }
        return cell
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sectionTitles
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let unwrappedSectionTitles = sectionTitles else {
            return nil
        }
        return section < unwrappedSectionTitles.count ? unwrappedSectionTitles[section] : nil
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            musicViewController = segue.destination as? MusicViewController
        }
        if segue.identifier == "ComposerSelected" {
            let secondViewController = segue.destination as! SelectedPiecesViewController
            if let selected = tableView?.indexPathForSelectedRow, let composerObjs = composerObjects {
                secondViewController.selectionField = "composer"
                let composerName = composerObjs[selected.section * sectionSize + selected.row]["composer"] as? String
                secondViewController.selectionValue = composerName
                secondViewController.displayTitle = composerName
            }
        }
    }
    
    // MARK: - UISearchResultsUpdating Delegate
    
    func updateSearchResults(for searchController: UISearchController) {
        //print("update to '\(searchController.searchBar.text ?? "")' filtering: \(isFiltering() ? "true" : "false")")
        updateUI()
    }
    
    private func searchBarIsEmpty() -> Bool {
        // Returns true if the text is empty or nil
        return searchController.searchBar.text?.isEmpty ?? true
    }

    private func isFiltering() -> Bool {
        return searchController.isActive && !searchBarIsEmpty()
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
            //NSLog("ComposersVC now playing item is '\(item?.title ?? "<sine nomine>")'")
            self.musicViewController?.nowPlayingItemDidChange(to: item)
        }
    }
    
    func playbackStateDidChange(to state: MPMusicPlaybackState) {
        DispatchQueue.main.async {
            self.musicViewController?.playbackStateDidChange(to: state)
        }
    }
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in
        (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)
    })
}
