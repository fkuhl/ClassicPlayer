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
    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var pieceTitle: UILabel!
    @IBOutlet weak var pieceArtist: UILabel!
}

class PiecesFromComposerViewController: UIViewController, NSFetchedResultsControllerDelegate, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    var selectedComposer: String?
    private var tableIsLoaded = false
    private var pieces: [Piece]?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 72.0
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fontSizeChanged),
                                               name: .UIContentSizeCategoryDidChange,
                                               object: nil)
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
        let request = NSFetchRequest<Piece>()
        request.entity = NSEntityDescription.entity(forEntityName: "Piece", in:context)
        request.predicate = NSPredicate(format: "composer == %@", selectedComposer!)
        request.resultType = .managedObjectResultType
        request.returnsDistinctResults = true
        request.sortDescriptors = [ NSSortDescriptor(key: "title", ascending: true) ]
        
        do {
            pieces = try context.fetch(request)
            tableView.reloadData()
        }
        catch {
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
    
    @objc private func fontSizeChanged() {
        DispatchQueue.main.async {
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pieces?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Piece", for: indexPath) as! PieceTableViewCell
        let pieceEntry = pieces![indexPath.row]
        cell.pieceTitle?.text = pieceEntry.title
        cell.pieceArtist?.text = pieceEntry.ensemble
        let id = pieceEntry.albumID
        if let realID = id {
            let returnedArtwork = AppDelegate.artworkFor(album: realID)
            if returnedArtwork != nil {
                cell.artwork.image = returnedArtwork
                cell.artwork.isOpaque = true
                cell.artwork.alpha = 1.0
           } else {
                cell.artwork.image = UIImage(named: "1706-music-note", in: nil, compatibleWith: nil)
                cell.artwork.isOpaque = false
                cell.artwork.alpha = 0.3
            }
        }
        //Priority lowered on artwork height to prevent unsatisfiable constraint.
        if UIApplication.shared.preferredContentSizeCategory > .extraExtraLarge {
            cell.artAndLabelsStack.axis = .vertical
            cell.artAndLabelsStack.alignment = .leading
        } else {
            cell.artAndLabelsStack.axis = .horizontal
            cell.artAndLabelsStack.alignment = .top
            //Content hugging priority lowered on text fields so they expand across the cell.
            cell.artAndLabelsStack.distribution = .fill
        }
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PieceSelected" {
            let secondViewController = segue.destination as! PieceViewController
            if let selected = tableView?.indexPathForSelectedRow {
                secondViewController.selectedPiece = pieces![selected.row]
            }
        }
    }

}
