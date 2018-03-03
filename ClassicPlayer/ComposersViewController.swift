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
    private var tableIsLoaded = false
    private var libraryAccessChecked = false
    
    private static var indexedSectionCount = 27  //A magic number; that's how many sections any UITableView index can have.
    private var composerObjects: [NSDictionary]?
    private var sectionCount = 1
    private var sectionSize = 0
    private var sectionTitles: [String]?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateUI),
                                               name: .dataAvailable,
                                               object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if libraryAccessChecked { return }
        //Check authorization to access media library
        MPMediaLibrary.requestAuthorization { status in
            switch status {
            case .notDetermined, .authorized:
                break
            case .restricted:
                self.alertAndExit(message: "Media library access restricted by corporate or parental controls")
            case .denied:
                self.alertAndExit(message: "Media library access denied by user")
            }
        }
        libraryAccessChecked = true
    }
    
    @objc
    private func updateUI() {
        DispatchQueue.main.async { //This may be called off the thread that handles notifications
            let context:NSManagedObjectContext! = (UIApplication.shared.delegate as! AppDelegate).context
            let request = NSFetchRequest<NSDictionary>()
            request.entity = NSEntityDescription.entity(forEntityName: "Piece", in:context!)
            request.resultType = .dictionaryResultType
            request.returnsDistinctResults = true
            request.propertiesToFetch = [ "composer" ]
            request.predicate = NSPredicate(format: "composer <> %@", "") //No blank composers!
            request.sortDescriptors = [ NSSortDescriptor(key: "composer", ascending: true) ]
            do {
                self.composerObjects = try context!.fetch(request)
                //print("fetch returned \(self.composerObjects!.count) composer things")
                self.computeSections()
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
            catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    @objc
    private func alertAndExit(message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "No Access to Media Library", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Go to Settings", style: .default, handler: { _ in
                UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
            }))
            self.present(alert, animated: true)
            //...aaand somehow the app is relaunching after this...
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

