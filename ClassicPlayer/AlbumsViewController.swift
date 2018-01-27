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
    @IBOutlet weak var stack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var albumTitle: UILabel!
    @IBOutlet weak var artist: UILabel!
    var stackWidthConstraint: NSLayoutConstraint?
}

fileprivate let sectionInsets = UIEdgeInsets(top: 50.0, left: 20.0, bottom: 50.0, right: 20.0)

class AlbumsViewController: UIViewController, NSFetchedResultsControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    @IBOutlet weak var collectionView: UICollectionView!
    private var collectionIsLoaded = false
    @IBOutlet weak var sortButton: UIButton!
    private var albums: [Album]?
    
    //We're all set up with sections and titles, and no automatic way to display them!
    static var indexedSectionCount = 27  //A magic number; that's how many sections any UITableView index can have.
    private var sectionCount = 1
    private var sectionSize = 0
    private var sectionTitles: [String]?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView.delegate = self //includes layout!
        self.collectionView.dataSource = self
        (self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.estimatedItemSize
            = UICollectionViewFlowLayoutAutomaticSize
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
            setInterlineSpacing()
            computeSections()
            collectionView.reloadData()
        }
        catch {
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
    
    private func computeSections() {
        guard let unwrappedAlbums = albums else {
            return
        }
        if unwrappedAlbums.count < AlbumsViewController.indexedSectionCount {
            sectionCount = 1
            sectionSize = unwrappedAlbums.count
            sectionTitles = []
        } else {
            sectionCount = AlbumsViewController.indexedSectionCount
            sectionSize = unwrappedAlbums.count / ComposersViewController.indexedSectionCount
            sectionTitles = []
            for i in 0 ..< AlbumsViewController.indexedSectionCount {
                let album = albums?[i * sectionSize]
                let composer = album?.title
                let title = composer?.prefix(2)
                //print("title \(i) is \(title ?? "nada")")
                sectionTitles?.append(String(title!))
            }
        }
    }

    private func setInterlineSpacing() {
        let subheadFont = UIFont.preferredFont(forTextStyle: .subheadline)
        print("line height of \(subheadFont.lineHeight) for font \(subheadFont)")
        (collectionView?.collectionViewLayout as? UICollectionViewFlowLayout)?.minimumLineSpacing = subheadFont.lineHeight * 2.0
        collectionView?.collectionViewLayout.invalidateLayout()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc
    func fontSizeChanged() {
        print("font size changed")
        setInterlineSpacing()
        collectionView?.collectionViewLayout.invalidateLayout()
    }

    // MARK: - UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sectionCount
    }
    
    func collectionView(_ collectionView: UICollectionView,
                                 numberOfItemsInSection section: Int) -> Int {
        if section < AlbumsViewController.indexedSectionCount - 1 {
            return sectionSize
        } else {
            //that pesky last section
            return albums!.count - AlbumsViewController.indexedSectionCount * sectionSize
        }
    }
    
    fileprivate let stackWidthIdentifier = "com.tyndalesoft.ClassicPlayer.stackWidth"
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Album",
                                                      for: indexPath) as! AlbumCell
        let albumEntry = albums![indexPath.section * sectionSize + indexPath.row]
        cell.albumTitle.text = albumEntry.title
        cell.artist.text = albumEntry.artist
       let id = albumEntry.albumID
        if let realID = id {
            let returnedArtwork = AppDelegate.artworkFor(album: realID)
            if returnedArtwork != nil {
                cell.artwork.image = returnedArtwork
//                let returnedFrame = cell.artwork.frame
//                if returnedFrame.height > 150 {
//                    //cell.artwork.frame = CGRect(origin: returnedFrame.origin, size: CGSize(width: returnedFrame.size.width, height: 150.0))
//                    print("title: \(albumEntry.title) oversized: \(returnedFrame.size)")
//                }
                cell.artwork.isOpaque = true
                cell.artwork.alpha = 1.0
            } else {
                cell.artwork.image = UIImage(named: "1706-music-note", in: nil, compatibleWith: nil)
                //cell.artwork.bounds = CGRect(x: 0, y: 0, width: 150, height: 150)
                cell.artwork.isOpaque = false
                cell.artwork.alpha = 0.3
            }
        }
        cell.contentView.translatesAutoresizingMaskIntoConstraints = false
        for constraint in cell.stack.constraints {
            if constraint.identifier == stackWidthIdentifier { cell.stack.removeConstraint(constraint) }
        }
        let widthConstraint = cell.stack.widthAnchor.constraint(equalToConstant: cellWidthForTextSize())
        widthConstraint.identifier = stackWidthIdentifier
        widthConstraint.isActive = true
        return cell
    }
    
    private func cellWidthForTextSize() -> CGFloat {
        let subheadFont = UIFont.preferredFont(forTextStyle: .subheadline)
        return max(150.0, 10.0 * subheadFont.pointSize) //10 is a magic number!
    }
    
    func indexTitles(for collectionView: UICollectionView) -> [String]? {
        return sectionTitles
    }

    // MARK: - UICollectionViewDelegateFlowLayout

//    func collectionView(_ collectionView: UICollectionView,
//                        layout collectionViewLayout: UICollectionViewLayout,
//                        sizeForItemAt indexPath: IndexPath) -> CGSize {
//        print("layout item \(indexPath.row) font size \(UIApplication.shared.preferredContentSizeCategory)")
//        let artHeight = 150
//        var stackHeight = 0, stackWidth = 0
//        switch UIApplication.shared.preferredContentSizeCategory {
//        case .extraLarge:
//            stackWidth = 150
//            stackHeight = artHeight + 22 + 22 + 19
//        case .extraExtraLarge:
//            stackWidth = 170
//            stackHeight = artHeight + 24 + 24 + 21
//        case .extraExtraExtraLarge:
//            stackWidth = 190
//            stackHeight = artHeight + 26 + 26 + 23
//        case .accessibilityMedium:
//            stackWidth = 210
//            stackHeight = artHeight + 31 + 31 + 28
//        case .accessibilityLarge:
//            stackWidth = 230
//            stackHeight = artHeight + 37 + 37 + 32
//        case .accessibilityExtraLarge:
//            stackWidth = 250
//            stackHeight = artHeight + 43 + 43 + 39
//        case .accessibilityExtraExtraLarge:
//            stackWidth = 270
//            stackHeight = artHeight + 50 + 50 + 44
//        case .accessibilityExtraExtraExtraLarge:
//            stackWidth = 290
//            stackHeight = artHeight + 58 + 58 + 51
//        default:
//            stackWidth = 150
//            stackHeight = artHeight + 20 + 20 + 16
//        }
//        return CGSize(width: stackWidth, height: stackHeight)
//    }
//
//    func collectionView(_ collectionView: UICollectionView,
//                        layout collectionViewLayout: UICollectionViewLayout,
//                        insetForSectionAt section: Int) -> UIEdgeInsets {
//        return sectionInsets
//    }

//    func collectionView(_ collectionView: UICollectionView,
//                        layout collectionViewLayout: UICollectionViewLayout,
//                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
//        let subheadFont = UIFont.preferredFont(forTextStyle: .subheadline)
//        print("line height of \(subheadFont.lineHeight) for font \(subheadFont)")
//        return subheadFont.lineHeight * 2.0
//    }


    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
}
