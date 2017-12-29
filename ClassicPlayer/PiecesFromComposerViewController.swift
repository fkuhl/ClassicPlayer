//
//  PiecesFromComposerViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 12/26/17.
//  Copyright © 2017 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import CoreData
import MediaPlayer

class PieceTableViewCell: UITableViewCell {
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var pieceTitle: UILabel!
    @IBOutlet weak var pieceArtist: UILabel!
}

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
            if let po = pieceObjects {
                for pieceObject in po {
                    print("  piece \(pieceObject["title"]) with \(pieceObject["ensemble"]) " +
                        "album \(pieceObject["albumID"]) track \(pieceObject["trackID"]))")
                }
            }
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "Piece", for: indexPath) as! PieceTableViewCell
        let pieceEntry = pieceObjects![indexPath.row]
        cell.pieceTitle?.text = pieceEntry["title"] as? String
        cell.pieceArtist?.text = pieceEntry["ensemble"] as? String
        //TODO how to set image? Maybe need custom cell I can set
        let id = pieceEntry["albumID"] as? String
        if let realID = id {
            cell.artwork.image = artworkFor(album: realID)
        }
        return cell
    }
    
    private func artworkFor(album: String) -> UIImage? {
        let query = MPMediaQuery.albums()
        let idVal = UInt64(album, radix: 16)
        let predicate = MPMediaPropertyPredicate(value: idVal, forProperty: MPMediaItemPropertyAlbumPersistentID)
        query.filterPredicates = Set([ predicate ])
        if query.collections == nil {
            print("album query produced nil")
            return nil
        }
        let results = query.collections!
        if results.count < 1 {
            print("album query had no hits")
            return nil
        }
        if results.count > 1 { print("album query had \(results.count) hits") }
        let result = results[0].items[0]
        let propertyVal = result.value(forProperty: MPMediaItemPropertyArtwork)
        let artwork = propertyVal as? MPMediaItemArtwork
        return artwork?.image(at: CGSize(width: 30, height: 30))
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
