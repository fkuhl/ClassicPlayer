//
//  SongsViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/27/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import CoreData
import AVFoundation
import AVKit
import MediaPlayer

class SongsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating {
    @IBOutlet weak var sortButton: UIBarButtonItem!
    @IBOutlet weak var trackTable: UITableView!
    let searchController = UISearchController(searchResultsController: nil)
    var playerViewController: AVPlayerViewController?
    weak var playerLabel: UILabel?
    var songs: [Song]?
    private var rateObserver = RateObserver()
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    private static var indexedSectionCount = 27  //A magic number; that's how many sections any UITableView index can have.
    private var sectionCount = 1
    private var sectionSize = 0
    private var sectionTitles: [String]?
    private var currentSort: SongSorts = .title

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Songs"
        trackTable.delegate = self
        trackTable.dataSource = self
        trackTable.rowHeight = UITableView.automaticDimension
        trackTable.estimatedRowHeight = 128.0
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Songs"
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSongsSortedBy(currentSort)
        playerViewController?.player = appDelegate.player.player
        if appDelegate.player.isActive {
            if appDelegate.player.setterID == mySetterID() {
                rateObserver.start(on: self)
            }
            playerLabel?.text = appDelegate.player.label
         } else {
            installPlayer(forIndex: 0)
        }
        trackTable.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        //print("PieceVC.viewWillDisappear")
        rateObserver.stop(on: self)
    }
    
    private func loadSongsSortedBy(_ sort: SongSorts) {
        do {
            let context:NSManagedObjectContext! = (UIApplication.shared.delegate as! AppDelegate).mainThreadContext
            let request = NSFetchRequest<Song>()
            request.entity = NSEntityDescription.entity(forEntityName: "Song", in:context)
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
            songs = try context.fetch(request)
            computeSections(forSort: sort)
            title = "Songs by \(sort.dropDownDisplayName)"
            trackTable.reloadData()
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
    
    private func computeSections(forSort sort: SongSorts) {
        guard let unwrappedSongs = songs else {
            return
        }
        if presentAsOneSection() {
            sectionCount = 1
            sectionSize = unwrappedSongs.count
            sectionTitles = []
            return
        }
        if unwrappedSongs.count < SongsViewController.indexedSectionCount {
            sectionCount = 1
            sectionSize = unwrappedSongs.count
            sectionTitles = []
        } else {
            sectionCount = SongsViewController.indexedSectionCount
            sectionSize = unwrappedSongs.count / SongsViewController.indexedSectionCount
            sectionTitles = []
            for i in 0 ..< SongsViewController.indexedSectionCount {
                let track = unwrappedSongs[i * sectionSize]
                let indexString = sort.sortField(from: track)
                let indexEntry = indexString.prefix(2)
                sectionTitles?.append(String(indexEntry))
            }
        }
    }
    
    private func presentAsOneSection() -> Bool {
        if songs == nil { return true }
        return songs!.count < SongsViewController.indexedSectionCount * 2
    }

    // MARK: - Sort popover
    
    @IBAction func sortButtonTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let sortVC = storyboard.instantiateViewController(withIdentifier: "SongsSortController")
            as! SongSortViewController
        sortVC.songsViewController = self
        sortVC.preferredContentSize = CGSize(width: 200, height: 200)
        sortVC.modalPresentationStyle = .popover
        sortVC.popoverPresentationController?.barButtonItem = sortButton
        self.present(sortVC, animated: true) { }
    }
    
    func userDidChoose(sort: SongSorts) { //this got called off the main thread, right?
        self.dismiss(animated: true) { }
        //sorting and reload will be done in VWA
        currentSort = sort
    }

    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionCount
    }
    
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if sectionCount == 1 {
            return songs?.count ?? 0
        }
        if section < SongsViewController.indexedSectionCount - 1 {
            return sectionSize
        } else {
            //that pesky last section
            return songs!.count - SongsViewController.indexedSectionCount * sectionSize
        }
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sectionTitles
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Track", for: indexPath) as! SongTableViewCell
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if indexPath.section * sectionSize + indexPath.row == appDelegate.player.currentTableIndex {
            if appDelegate.player.player.rate < 0.5 {
                cell.indicator.stopAnimating()
                cell.indicator.animationImages = nil
                cell.indicator.image = appDelegate.audioPaused
            } else {
                cell.indicator.image = nil
                cell.indicator.animationImages = appDelegate.audioBarSet
                cell.indicator.animationRepeatCount = 0 //like, forever
                cell.indicator.animationDuration = 0.6  //sec
                cell.indicator.startAnimating()
            }
            cell.artwork.isOpaque = false
            cell.artwork.alpha = 0.5
       } else {
            cell.indicator.stopAnimating()
            cell.indicator.animationImages = nil
            cell.indicator.image = appDelegate.audioNotCurrent
            cell.artwork.isOpaque = true
            cell.artwork.alpha = 1.0
        }
        let song = songs![indexPath.section * sectionSize + indexPath.row]
        let id = song.albumID
        cell.artwork.image = AppDelegate.artworkFor(album: id!)
        cell.title.text = song.title
        cell.artist.text = song.artist
        cell.duration.text = song.duration
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

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let currentIndex = indexPath.section * sectionSize + indexPath.row
        installPlayer(forIndex: currentIndex)
        playerViewController?.player?.play() //start 'er up
        tableView.reloadData()
    }
    
    private func labelForPlayer(atIndex: Int) -> String {
        let artist = songs![atIndex].artist
        let title = songs![atIndex].title
        if let uArtist = artist {
            return uArtist + ": " + (title ?? "")
        } else {
            return title ?? ""
        }
    }
    
    private func mySetterID() -> String {
        return Bundle.main.bundleIdentifier! + ".SongsViewController"
    }
    
    // MARK: - UISearchResultsUpdating Delegate
    
    func updateSearchResults(for searchController: UISearchController) {
        loadSongsSortedBy(currentSort)
        installPlayer(forIndex: 0)
    }
    
    private func searchBarIsEmpty() -> Bool {
        // Returns true if the text is empty or nil
        return searchController.searchBar.text?.isEmpty ?? true
    }
    
    private func isFiltering() -> Bool {
        return searchController.isActive && !searchBarIsEmpty()
    }

    // MARK: - Player management
    
    //The embed segue that places the AVPlayerViewController in the ContainerVC
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            //print("SongsVC.prepareForSegue")
            self.playerViewController = segue.destination as? AVPlayerViewController
            //This installs the UILabel. After this, we just change the text.
            playerLabel = ClassicPlayer.add(label: "not init", to: playerViewController!)
        }
    }

    private func installPlayer(forIndex: Int) {
        if songs != nil && songs!.count > 0 {
            rateObserver.stop(on: self)
            playerViewController?.player = appDelegate.player.setPlayer(url: (songs?[forIndex].trackURL)!,
                                                                        tableIndex: forIndex,
                                                                        setterID: mySetterID(),
                                                                        label: labelForPlayer(atIndex: forIndex))
            playerLabel?.text = labelForPlayer(atIndex: forIndex)
            playerViewController?.contentOverlayView?.setNeedsDisplay()
            rateObserver.start(on: self)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayer.rate) {
            if let _ = change?[.newKey] as? NSNumber {
                DispatchQueue.main.async { self.trackTable.reloadData() }
            }
        }
    }

}
