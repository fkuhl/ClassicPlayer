//
//  SongsViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/27/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import CoreData
import MediaPlayer

class SongsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, MusicObserverDelegate {
    
    @IBOutlet weak var sortButton: UIBarButtonItem!
    @IBOutlet weak var trackTable: UITableView!
    let searchController = UISearchController(searchResultsController: nil)
    weak var musicViewController: MusicViewController?
    var songs: [Song]?
    private var musicObserver = MusicObserver()
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
        if musicPlayerPlaybackState() == .playing {
            musicViewController?.nowPlayingItemDidChange(to: MPMusicPlayerController.applicationMusicPlayer.nowPlayingItem)
            musicObserver.start(on: self)
            if appDelegate.musicPlayer.setterID == mySetterID() {
                scrollToCurrent()
            }
       } else {
            installPlayer(forIndex: 0, paused: true)
        }
        trackTable.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        //print("PieceVC.viewWillDisappear")
        musicObserver.stop()
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
    
    //The embed segue that places the MusicViewController in the ContainerVC
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            self.musicViewController = segue.destination as? MusicViewController
        }
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
        if appDelegate.musicPlayer.setterID == mySetterID() &&
            indexPath.section * sectionSize + indexPath.row == appDelegate.musicPlayer.currentTableIndex {
            if musicPlayerPlaybackState() == .playing {
                cell.indicator.image = nil
                cell.indicator.animationImages = appDelegate.audioBarSet
                cell.indicator.animationRepeatCount = 0 //like, forever
                cell.indicator.animationDuration = 0.6  //sec
                cell.indicator.startAnimating()
            } else {
                cell.indicator.stopAnimating()
                cell.indicator.animationImages = nil
                cell.indicator.image = appDelegate.audioPaused
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
        installPlayer(forIndex: currentIndex, paused: false)
        //playerViewController?.play() //start 'er up
        tableView.reloadData()
    }
    
    // MARK: - UISearchResultsUpdating Delegate
    
    func updateSearchResults(for searchController: UISearchController) {
        loadSongsSortedBy(currentSort)
        installPlayer(forIndex: 0, paused: true)
    }
    
    private func searchBarIsEmpty() -> Bool {
        // Returns true if the text is empty or nil
        return searchController.searchBar.text?.isEmpty ?? true
    }
    
    private func isFiltering() -> Bool {
        return searchController.isActive && !searchBarIsEmpty()
    }

    // MARK: - Player management

    private func installPlayer(forIndex index: Int, paused: Bool) {
        if songs != nil && songs!.count > 0 {
            var itemsToPlay = [MPMediaItem]()
            if let retrieved = retrieveItem(forIndex: index) {
                itemsToPlay.append(retrieved)
            }
//            if let retrieved = retrieveItem(forIndex: index+1) {
//                itemsToPlay.append(retrieved)
//            }
//            if let retrieved = retrieveItem(forIndex: index+2) {
//                itemsToPlay.append(retrieved)
//            }
            musicObserver.stop()
            appDelegate.musicPlayer.setPlayer(items: itemsToPlay,
                                              tableIndex: index,
                                              setterID: mySetterID(),
                                              paused: paused)
            musicViewController?.setInitialItem(item: itemsToPlay[0])
            musicObserver.start(on: self)
        }
    }

    private func retrieveItem(forIndex index: Int) -> MPMediaItem? {
        var item: MPMediaItem?
        if songs != nil && songs!.count > 0 {
            let persistentID = AppDelegate.decodeIDFrom(coreDataRepresentation: songs![index].persistentID!)
            let songQuery = MPMediaQuery.songs()
            let predicate = MPMediaPropertyPredicate(value: persistentID, forProperty: MPMediaItemPropertyPersistentID)
            songQuery.addFilterPredicate(predicate)
            if let returned = songQuery.items {
                if returned.count > 0 { item = returned[0] }
            }
        }
        return item
    }
    
    private func mySetterID() -> String {
        return Bundle.main.bundleIdentifier! + ".SongsViewController"
    }

    // MARK: - MusicObserverDelegate

    
    func nowPlayingItemDidChange(to item: MPMediaItem?) {
        DispatchQueue.main.async {
            self.trackTable.reloadData()
            self.musicViewController?.nowPlayingItemDidChange(to: item)
            self.scrollToCurrent()
        }
    }
    
    private func scrollToCurrent() {
        //As of iOS 11, the scroll seems to need a little delay.
        let deadlineTime = DispatchTime.now() + .milliseconds(100)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            if let visibleIndexPaths = self.trackTable.indexPathsForVisibleRows {
                let currentPath = IndexPath(indexes: [0, self.appDelegate.musicPlayer.currentTableIndex])
                if !visibleIndexPaths.contains(currentPath) {
                    self.trackTable.scrollToRow(at: currentPath, at: .bottom, animated: true)
                }
            }
        }
    }

    func playbackStateDidChange(to state: MPMusicPlaybackState) {
        DispatchQueue.main.async {
            self.trackTable.reloadData()
            self.musicViewController?.playbackStateDidChange(to: state)
        }
    }

}
