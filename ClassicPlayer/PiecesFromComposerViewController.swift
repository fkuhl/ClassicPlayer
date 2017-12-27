//
//  PiecesFromComposerViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 12/26/17.
//  Copyright © 2017 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import CoreData

class PiecesFromComposerViewController: UIViewController, NSFetchedResultsControllerDelegate, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    var selectedComposer: String?
    private var tableIsLoaded = false
    private var pieceObjects: [NSDictionary]?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
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

    private func updateUI() {
        self.title = selectedComposer
        let context:NSManagedObjectContext! = (UIApplication.shared.delegate as! AppDelegate).context
        let request = NSFetchRequest<NSDictionary>()
        request.entity = NSEntityDescription.entity(forEntityName: "Piece", in:context)
        request.predicate = NSPredicate(format: "composer == %@", selectedComposer!)
        request.resultType = .dictionaryResultType
        request.returnsDistinctResults = true
        request.propertiesToFetch = [ "title", "albumID", "trackID", "ensemble" ]
        request.sortDescriptors = [ NSSortDescriptor(key: "title", ascending: true) ]
        
        do {
            pieceObjects = try context.fetch(request)
//            print("fetch returned \(pieceObjects!.count) pieces for \(selectedComposer ?? "")")
//            if let po = pieceObjects {
//                for pieceObject in po {
//                    print("  piece \(pieceObject["title"]) with \(pieceObject["ensemble"]) " +
//                        "album \(pieceObject["albumID"]) track \(pieceObject["trackID"]))")
//                }
//            }
            tableView.reloadData()
        }
        catch {
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
    
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pieceObjects?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Piece", for: indexPath)
        let pieceEntry = pieceObjects![indexPath.row]
        cell.textLabel?.text = pieceEntry["title"] as? String
        cell.detailTextLabel?.text = pieceEntry["ensemble"] as? String
        //TODO how to set image? Maybe need custom cell I can set
        //cell.imageView = artworkFor(album: pieceEntry["albumID"])
        return cell
    }
    
    private func artworkFor(album: String) -> UIImageView? {
        //do MPMediaQuery to retrieve artwork
        //TODO
        return nil
    }
    
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        if segue.identifier == "ComposerSelected" {
//            let secondViewController = segue.destination as! PiecesFromComposerViewController
//            if let selected = tableView?.indexPathForSelectedRow {
//                secondViewController.selectedComposer =
//                    composerObjects![selected.section * sectionSize + selected.row]["composer"] as? String
//            }
//        }
//    }
}
