//
//  AlbumsViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/24/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import CoreData

class AlbumCell: UITableViewCell {
    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var albumTitle: UILabel!
    @IBOutlet weak var composer: UILabel!
    @IBOutlet weak var albumArtist: UILabel!
    @IBOutlet weak var year: UILabel!
    @IBOutlet weak var trackCount: UILabel!
}

class AlbumsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var sortButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!
    private var collectionIsLoaded = false
    private var albums: [Album]?
    
    static var indexedSectionCount = 27  //A magic number; that's how many sections any UITableView index can have.
    private var sectionCount = 1
    private var sectionSize = 0
    private var sectionTitles: [String]?
 
    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.rowHeight = UITableViewAutomaticDimension //Autolayout determines height!
        self.tableView.estimatedRowHeight = 128.0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !collectionIsLoaded {
            updateUI()
            collectionIsLoaded = true
        }
    }
 
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private func updateUI() {
        do {
            try loadAlbumsSortedBy(.title)
        }
        catch {
             let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
    
    private func loadAlbumsSortedBy(_ sort: AlbumSorts) throws {
        let context:NSManagedObjectContext! = (UIApplication.shared.delegate as! AppDelegate).context
        let request = NSFetchRequest<Album>()
        request.entity = NSEntityDescription.entity(forEntityName: "Album", in:context)
        //request.predicate = NSPredicate(format: "composer == %@", selectedComposer!)
        request.resultType = .managedObjectResultType
        request.returnsDistinctResults = true
        request.sortDescriptors = [ NSSortDescriptor(key: sort.sortDescriptor, ascending: true) ]
        albums = try context.fetch(request)
        computeSectionsSortedBy(sort)
        tableView.reloadData()
    }
    
    private func computeSectionsSortedBy(_ sort: AlbumSorts) {
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
                let indexString: String
                switch (sort) {
                case .title:
                    indexString = album?.title ?? ""
                case .composer:
                    indexString = album?.composer ?? "[]"
                case .artist:
                    indexString = album?.artist ?? ""
                case .genre:
                    indexString = album?.genre ?? ""
                }
                let indexEntry = indexString.prefix(2)
                sectionTitles?.append(String(indexEntry))
            }
        }
    }
    
    // MARK: - Sort popover

    @IBAction func sortButtonTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let sortVC = storyboard.instantiateViewController(withIdentifier: "AlbumsSortController")
            as! AlbumSortViewController
        sortVC.albumsViewController = self
        sortVC.preferredContentSize = CGSize(width: 200, height: 200)
        sortVC.modalPresentationStyle = .popover
        sortVC.popoverPresentationController?.barButtonItem = sortButton
        self.present(sortVC, animated: true) { }
    }
    
    func userDidChoose(sort: AlbumSorts) {
        self.dismiss(animated: true) { }
        do {
            try loadAlbumsSortedBy(sort)
        }
        catch {
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
    
    // MARK: - UITableViewDataSource

    func numberOfSections(in collectionView: UITableView) -> Int {
        return sectionCount
    }
    
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < AlbumsViewController.indexedSectionCount - 1 {
            return sectionSize
        } else {
            //that pesky last section
            return albums!.count - AlbumsViewController.indexedSectionCount * sectionSize
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Album", for: indexPath) as! AlbumCell
        let albumEntry = albums![indexPath.section * sectionSize + indexPath.row]
        cell.albumTitle?.text = albumEntry.title
        cell.composer?.text = albumEntry.composer ?? "[]"
        cell.albumArtist?.text = albumEntry.artist
        let yearText: String
        if let timeInterval = albumEntry.releaseDate?.timeIntervalSince1970 {
            let releaseDate = Date(timeIntervalSince1970: timeInterval)
            let calendar = Calendar.current
            yearText = "\(calendar.component(.year, from: releaseDate))"
        } else {
            yearText = "[n.d.]"
        }
        cell.year?.text = "\(yearText) • \(albumEntry.genre ?? "")"
        cell.trackCount?.text = "tracks: \(albumEntry.trackCount)"
        let id = albumEntry.albumID
        if let realID = id {
            let returnedArtwork = AppDelegate.artworkFor(album: realID)
            if returnedArtwork != nil {
                cell.artwork.image = returnedArtwork
                cell.artwork.isOpaque = true
                cell.artwork.alpha = 1.0
            } else {
                cell.artwork.image = AppDelegate.defaultImage
                cell.artwork.isOpaque = false
                cell.artwork.alpha = 0.3
            }
        }
        //Priority lowered on artwork height to prevent unsatisfiable constraint.
        //As of 1/31/2018, a change in text size in medias res causes the cells to re-layout
        //properly but the text itself doesn't change size!
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
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sectionTitles
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "AlbumSelected" {
            let secondViewController = segue.destination as! AlbumTracksViewController
            if let selected = tableView?.indexPathForSelectedRow {
                secondViewController.album =
                    albums![selected.section * sectionSize + selected.row]
                secondViewController.title = secondViewController.album?.title
            }
        }
    }
}
