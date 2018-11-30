//
//  AlbumsViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/24/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import CoreData
import AVFoundation
import AVKit

class AlbumCell: UITableViewCell {
    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var albumTitle: UILabel!
    @IBOutlet weak var composer: UILabel!
    @IBOutlet weak var albumArtist: UILabel!
    @IBOutlet weak var year: UILabel!
    @IBOutlet weak var trackCount: UILabel!
}

class AlbumsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating {
    @IBOutlet weak var sortButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!
    let searchController = UISearchController(searchResultsController: nil)
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var albums: [Album]?
    
    private static var indexedSectionCount = 27  //A magic number; that's how many sections any UITableView index can have.
    private var sectionCount = 1
    private var sectionSize = 0
    private var sectionTitles: [String]?
    private var currentSort: AlbumSorts = .title
    weak var playerViewController: AVPlayerViewController?
    weak var playerLabel: UILabel?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        //NSLog("AlbumsVC.VDL")
       self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.rowHeight = UITableView.automaticDimension //Autolayout determines height!
        self.tableView.estimatedRowHeight = 128.0
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Albums"
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        playerViewController?.player = appDelegate.player.player
        playerLabel?.text = appDelegate.player.label
        //NSLog("AlbumsVC.VWA")
        //This load is fast enough there's no reason not to do it every time,
        //thus dealing with changes to the library since last appearance
        loadAlbumsSortedBy(currentSort)
     }
 
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func loadAlbumsSortedBy(_ sort: AlbumSorts) {
        do {
            let context:NSManagedObjectContext! = (UIApplication.shared.delegate as! AppDelegate).mainThreadContext
            let request = NSFetchRequest<Album>()
            request.entity = NSEntityDescription.entity(forEntityName: "Album", in:context)
            request.resultType = .managedObjectResultType
            request.returnsDistinctResults = true
            if isFiltering() {
                //filter on the sort descriptor
                let format = "\(sort.sortDescriptor) CONTAINS[cd] %@"
                request.predicate = NSPredicate(format: format, searchController.searchBar.text!)
            }
            request.sortDescriptors = [ NSSortDescriptor(key: sort.sortDescriptor,
                                                         ascending: true,
                                                         selector: #selector(NSString.localizedCaseInsensitiveCompare)) ]
            albums = try context.fetch(request)
            computeSectionsSortedBy(sort)
            title = "Albums by \(sort.dropDownDisplayName)"
            tableView.reloadData()
        }
        catch {
            let nserror = error as NSError
            let message = "\(String(describing: nserror.userInfo))"
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Error retrieving app data", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Exit App", style: .default, handler: { _ in
                    exit(1)
                }))
                self.present(alert, animated: true)
            }
        }
    }
    
    private func computeSectionsSortedBy(_ sort: AlbumSorts) {
        guard let unwrappedAlbums = albums else {
            return
        }
        if presentAsOneSection() {
            sectionCount = 1
            sectionSize = unwrappedAlbums.count
            sectionTitles = []
            return
        }
        sectionCount = AlbumsViewController.indexedSectionCount
        sectionSize = unwrappedAlbums.count / AlbumsViewController.indexedSectionCount
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
    
    private func presentAsOneSection() -> Bool {
        if albums == nil { return true }
        return albums!.count < AlbumsViewController.indexedSectionCount * 2
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
        //sorting and reload will be done in VWA
        currentSort = sort
    }
    
    // MARK: - UITableViewDataSource

    func numberOfSections(in collectionView: UITableView) -> Int {
        return sectionCount
    }
    
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if sectionCount == 1 {
            return albums?.count ?? 0
        }
        if section < AlbumsViewController.indexedSectionCount - 1 {
            return sectionSize
        } else {
            //that pesky last section
            return albums!.count - AlbumsViewController.indexedSectionCount * sectionSize
        }
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sectionTitles
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Album", for: indexPath) as! AlbumCell
        let albumEntry = albums![indexPath.section * sectionSize + indexPath.row]
        cell.albumTitle?.text = albumEntry.title
        cell.composer?.text = albumEntry.composer ?? ""
        cell.albumArtist?.text = albumEntry.artist
        let yearText = albumEntry.year > 0 ? "\(albumEntry.year)" : "[n.d.]"
        cell.year?.text = "\(yearText) • \(albumEntry.genre ?? "")"
        //There may not have been an entry for track counts in the iTunes data
        cell.trackCount?.text = (albumEntry.trackCount > 0) ? "tracks: \(albumEntry.trackCount)" : ""
        let id = albumEntry.albumID
        if let realID = id {
            cell.artwork.image = AppDelegate.artworkFor(album: realID)
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
        if segue.identifier == "PlayTracks" {
            print("AlbumsVC.prepareForSegue. playerVC: \(segue.destination)")
            playerViewController = segue.destination as? AVPlayerViewController
            //This installs the UILabel. After this, we just change the text.
            playerLabel = add(label: "not init", to: playerViewController!)
        }
        if segue.identifier == "AlbumSelected" {
            let secondViewController = segue.destination as! AlbumTracksViewController
            if let selected = tableView?.indexPathForSelectedRow {
                secondViewController.album =
                    albums![selected.section * sectionSize + selected.row]
                secondViewController.title = secondViewController.album?.title
            }
        }
    }
    
    // MARK: - UISearchResultsUpdating Delegate
    
    func updateSearchResults(for searchController: UISearchController) {
        loadAlbumsSortedBy(currentSort)
    }
    
    private func searchBarIsEmpty() -> Bool {
        // Returns true if the text is empty or nil
        return searchController.searchBar.text?.isEmpty ?? true
    }
    
    private func isFiltering() -> Bool {
        return searchController.isActive && !searchBarIsEmpty()
    }
}
