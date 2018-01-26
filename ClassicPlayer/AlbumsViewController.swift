//
//  AlbumsViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/24/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import CoreData

class AlbumCell: UICollectionViewCell {
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var albumTitle: UILabel!
    @IBOutlet weak var artist: UILabel!
}

class AlbumsViewController: UIViewController, NSFetchedResultsControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource {
    @IBOutlet weak var collectionView: UICollectionView!
    private var collectionIsLoaded = false
    @IBOutlet weak var sortButton: UIButton!
    private var albums: [Album]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !collectionIsLoaded {
            updateUI()
            collectionIsLoaded = true
        }
    }
    
    private func updateUI() {
        let context:NSManagedObjectContext! = (UIApplication.shared.delegate as! AppDelegate).context
        let request = NSFetchRequest<Album>()
        request.entity = NSEntityDescription.entity(forEntityName: "Album", in:context)
        //request.predicate = NSPredicate(format: "composer == %@", selectedComposer!)
        request.resultType = .managedObjectResultType
        request.returnsDistinctResults = true
        request.sortDescriptors = [ NSSortDescriptor(key: "title", ascending: true) ]
        do {
            albums = try context.fetch(request)
            collectionView.reloadData()
        }
        catch {
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView,
                                 numberOfItemsInSection section: Int) -> Int {
        return albums?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Album",
                                                      for: indexPath) as! AlbumCell
        let albumEntry = albums![indexPath.row]
        cell.albumTitle.text = albumEntry.title
        cell.artist.text = albumEntry.artist
       let id = albumEntry.albumID
        if let realID = id {
            let returnedArtwork = AppDelegate.artworkFor(album: realID)
            if returnedArtwork != nil {
                cell.artwork.image = returnedArtwork
                cell.artwork.isOpaque = true
                cell.artwork.alpha = 1.0
            } else {
                cell.artwork.image = UIImage(named: "1706-music-note", in: nil, compatibleWith: nil)
                //cell.artwork.bounds = CGRect(x: 0, y: 0, width: 150, height: 150)
                cell.artwork.isOpaque = false
                cell.artwork.alpha = 0.3
            }
        }
        return cell
    }


    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
}
