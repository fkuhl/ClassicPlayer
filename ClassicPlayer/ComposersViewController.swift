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

class ComposersViewController: UIViewController, NSFetchedResultsControllerDelegate, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityBackground: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    private var tableIsLoaded = false
    private var libraryAccessChecked = false
    
    private static var indexedSectionCount = 27  //A magic number; that's how many sections any UITableView index can have.
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var composerObjects: [NSDictionary]?
    private var sectionCount = 1
    private var sectionSize = 0
    private var sectionTitles: [String]?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.activityBackground.isHidden = true
        self.activityIndicator.isHidden = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateUI),
                                               name: .dataAvailable,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(libraryDidChange),
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
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if libraryAccessChecked { return }
        //Check authorization to access media library
        MPMediaLibrary.requestAuthorization { status in
            switch status {
            case .notDetermined:
                break //not clear how you'd ever get here, as the request will determine authorization
            case .authorized:
                self.appDelegate.checkLibraryChanged()
            case .restricted:
                self.alertAndGoToSettings(message: "Media library access restricted by corporate or parental controls")
            case .denied:
                self.alertAndGoToSettings(message: "Media library access denied by user")
            }
            self.libraryAccessChecked = true
       }
    }
    
    @objc
    private func updateUI() {
        let context:NSManagedObjectContext! = self.appDelegate.context
        let request = NSFetchRequest<NSDictionary>()
        request.entity = NSEntityDescription.entity(forEntityName: "Piece", in:context!)
        request.resultType = .dictionaryResultType
        request.returnsDistinctResults = true
        request.propertiesToFetch = [ "composer" ]
        request.predicate = NSPredicate(format: "composer <> %@", "") //No blank composers!
        request.sortDescriptors = [ NSSortDescriptor(key: "composer",
                                                     ascending: true,
                                                     selector: #selector(NSString.localizedCaseInsensitiveCompare)) ]
        do {
            self.composerObjects = try context!.fetch(request)
            //NSLog("fetch returned \(self.composerObjects!.count) composer things")
            self.computeSections()
            DispatchQueue.main.async {
                self.tableView.reloadData()
                NSLog("stopping animation")
                self.activityIndicator.stopAnimating()
                self.activityBackground.isHidden = true
                self.activityIndicator.isHidden = true
           }
        }
        catch {
            let error = error as NSError
            let message = "\(String(describing: error.userInfo))"
            NSLog("error retrieving composers: \(error), \(error.userInfo)")
            alertAndExit(title: "Error Retrieving Composers", message: message)
        }
    }
    
    @objc
    private func libraryDidChange() {
        DispatchQueue.main.async {
            //The actions are dispatched async to avoid the dread "_BSMachError"
            let alert = UIAlertController(title: "iTunes Library Changed",
                                          message: "Load newest media?",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Load newest media", style: .destructive, handler: { _ in
                DispatchQueue.main.async {
                    self.activityBackground.isHidden = false
                    self.activityIndicator.isHidden = false
                    self.activityIndicator.startAnimating()
                    self.view.setNeedsDisplay()
                    NSLog("started animation")
                    //DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5), execute: {
                    self.appDelegate.replaceAppLibraryWithMedia()
                    //})
                }
            }))
            alert.addAction(UIAlertAction(title: "Skip the load for now", style: .cancel, handler: { _ in
                DispatchQueue.main.async {
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
            let alert = UIAlertController(title: "No Access to Media Library", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Go to Settings", style: .default, handler: { _ in
                DispatchQueue.main.async {
                    UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!,
                                              options: [:],
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

    private func computeSections() {
        if let composers = composerObjects {
            if composers.count < ComposersViewController.indexedSectionCount {
                sectionCount = 1
                sectionSize = composers.count
                sectionTitles = []
            } else {
                sectionCount = ComposersViewController.indexedSectionCount
                sectionSize = composers.count / ComposersViewController.indexedSectionCount
                sectionTitles = []
                for i in 0 ..< ComposersViewController.indexedSectionCount {
                    let dict = composers[i * sectionSize]
                    let composer = dict["composer"] as? String
                    let title = composer?.prefix(2)
                    //print("title \(i) is \(title ?? "nada")")
                    sectionTitles?.append(String(title!))
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !tableIsLoaded {
            updateUI()
            tableIsLoaded = true
        }
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
        if section < ComposersViewController.indexedSectionCount - 1 {
            return sectionSize
        } else {
            //that pesky last section
            return composerObjects!.count - ComposersViewController.indexedSectionCount * sectionSize
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Composer", for: indexPath)
        let composerEntry = composerObjects![indexPath.section * sectionSize + indexPath.row]
        let reportedComposer = composerEntry["composer"] as? String
        cell.textLabel?.text = (reportedComposer == "") ? "[no composer listed]" : reportedComposer
        return cell
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sectionTitles
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ComposerSelected" {
            let secondViewController = segue.destination as! SelectedPiecesViewController
            if let selected = tableView?.indexPathForSelectedRow {
                secondViewController.selectionField = "composer"
                let composerName = composerObjects![selected.section * sectionSize + selected.row]["composer"] as? String
                secondViewController.selectionValue = composerName
                secondViewController.displayTitle = composerName
            }
        }
    }
}

