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

fileprivate let sectionInsets = UIEdgeInsets(top: 50.0, left: 20.0, bottom: 50.0, right: 20.0)

class AlbumsViewController: UIViewController, NSFetchedResultsControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    @IBOutlet weak var collectionView: UICollectionView!
    private var collectionIsLoaded = false
    @IBOutlet weak var sortButton: UIButton!
    private var albums: [Album]?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView.delegate = self //includes layout!
        self.collectionView.dataSource = self
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fontSizeChanged),
                                               name: .UIContentSizeCategoryDidChange,
                                               object: nil)
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
    
    @objc
    func fontSizeChanged() {
        print("font size changed")
        collectionView?.collectionViewLayout.invalidateLayout()
    }

    // MARK: - UICollectionViewDataSource

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

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        print("layout item \(indexPath.row) font size \(UIApplication.shared.preferredContentSizeCategory)")
        let artHeight = 150
        var stackHeight = 0, stackWidth = 0
        switch UIApplication.shared.preferredContentSizeCategory {
        case .extraLarge:
            stackWidth = 150
            stackHeight = artHeight + 22 + 22 + 19
        case .extraExtraLarge:
            stackWidth = 170
            stackHeight = artHeight + 24 + 24 + 21
        case .extraExtraExtraLarge:
            stackWidth = 190
            stackHeight = artHeight + 26 + 26 + 23
        case .accessibilityMedium:
            stackWidth = 210
            stackHeight = artHeight + 31 + 31 + 28
        case .accessibilityLarge:
            stackWidth = 230
            stackHeight = artHeight + 37 + 37 + 32
        case .accessibilityExtraLarge:
            stackWidth = 250
            stackHeight = artHeight + 43 + 43 + 39
        case .accessibilityExtraExtraLarge:
            stackWidth = 270
            stackHeight = artHeight + 50 + 50 + 44
        case .accessibilityExtraExtraExtraLarge:
            stackWidth = 290
            stackHeight = artHeight + 58 + 58 + 51
        default:
            stackWidth = 150
            stackHeight = artHeight + 20 + 20 + 16
        }
        return CGSize(width: stackWidth, height: stackHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return sectionInsets
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return sectionInsets.left
    }


    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
}
