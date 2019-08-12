//
//  ArtistsViewController
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 2/13/2018.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import MediaPlayer

class ArtistsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, MusicObserverDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var playerViewHeight: NSLayoutConstraint!
    let searchController = UISearchController(searchResultsController: nil)
    private var tableIsLoaded = false
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    private static var indexedSectionCount = 27  //A magic number; that's how many sections any UITableView index can have.
    private var artistObjects: [MPMediaItem]?
    private var sectionCount = 1
    private var sectionSize = 0
    private var sectionTitles: [String]?
    weak var musicViewController: MusicViewController?
    private var musicObserver = MusicObserver()

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.rowHeight = UITableView.automaticDimension //Autolayout determines height!
        self.tableView.estimatedRowHeight = 64.0
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Artists"
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if musicPlayerPlaybackState() == .playing {
            playerViewHeight.constant = MusicPlayer.height
            musicViewController?.nowPlayingItemDidChange(to: MPMusicPlayerController.applicationMusicPlayer.nowPlayingItem)
            musicObserver.start(on: self)
        } else {
            playerViewHeight.constant = 0.0
        }
        updateUI()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        musicObserver.stop()
    }

    private func updateUI() {
        let query = MPMediaQuery.artists()
        artistObjects = []
        if let collections = query.collections {
            for collection in collections {
                if let firstItem = collection.items.first  {
                    if isFiltering(), let artist = firstItem.artist, let searchText = searchController.searchBar.text {
                        if artist.localizedCaseInsensitiveContains(searchText) {
                            artistObjects!.append(firstItem)
                        }
                    } else {
                        artistObjects!.append(firstItem)
                    }
                }
            }
        }
        computeSections()
        tableView.reloadData()
       //Artists are returned in "sort" order, so "The Beatles" sorts as "Beatles"
        //If I sort here, it's on "The Beatles"
        //        artistObjects = artistObjects?.sorted {
        //            ao1, ao2 in
        //            return ao1.artist ?? "" < ao2.artist ?? ""
        //        }
        //print("found \(query.collections!.count) artists")
    }
    
    private func computeSections() {
        guard let unwrappedArtistObjects = artistObjects else {
            sectionCount = 1
            sectionSize = 0
            return
        }
        if presentAsOneSection() {
            sectionCount = 1
            sectionSize = unwrappedArtistObjects.count
            sectionTitles = []
            return
        }
        if unwrappedArtistObjects.count < ArtistsViewController.indexedSectionCount {
            sectionCount = 1
            sectionSize = unwrappedArtistObjects.count
            sectionTitles = []
        } else {
            sectionCount = ArtistsViewController.indexedSectionCount
            sectionSize = unwrappedArtistObjects.count / ArtistsViewController.indexedSectionCount
            sectionTitles = []
            for i in 0 ..< ArtistsViewController.indexedSectionCount {
                let item = unwrappedArtistObjects[i * sectionSize]
                //media lib returns artists anarthrously; make section titles correspond
                let artist = removeArticle(from: (item.artist ?? ""))
                let title = artist.prefix(2)
                //print("title \(i) is \(title ?? "nada")")
                sectionTitles?.append(String(title))
            }
        }
    }
    
    private func presentAsOneSection() -> Bool {
        if artistObjects == nil { return true }
        return artistObjects!.count < ArtistsViewController.indexedSectionCount * 3
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionCount
    }
    
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < ArtistsViewController.indexedSectionCount - 1 {
            return sectionSize
        } else {
            //that pesky last section
            if let unwrappedArtistObjects = artistObjects {
                return unwrappedArtistObjects.count - (sectionCount - 1) * sectionSize
            } else {
                return 0
            }
            
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Artist", for: indexPath)
        let cellIndex = indexPath.section * sectionSize + indexPath.row
        if let unwrappedArtistObjects = artistObjects, unwrappedArtistObjects.count > cellIndex {
            let artistEntry = artistObjects![cellIndex]
            cell.textLabel?.text = artistEntry.artist
        }
        return cell
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sectionTitles
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let unwrappedSectionTitles = sectionTitles else {
            return nil
        }
        return section < unwrappedSectionTitles.count ? unwrappedSectionTitles[section] : nil
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            musicViewController = segue.destination as? MusicViewController
        }
        if segue.identifier == "ArtistSelected" {
            let secondViewController = segue.destination as! SelectedPiecesViewController
            if let selected = tableView?.indexPathForSelectedRow {
                secondViewController.selectionField = "artistID"
                let cellIndex = selected.section * sectionSize + selected.row
                if let unwrappedArtistObjects = artistObjects, unwrappedArtistObjects.count > cellIndex {
                    let selectedArtist = unwrappedArtistObjects[cellIndex]
                    let artistID = selectedArtist.artistPersistentID
                    secondViewController.selectionValue = ClassicalMediaLibrary.encodeForCoreData(id: artistID)
                    secondViewController.displayTitle = selectedArtist.artist
                }
            }
        }
    }
    
    // MARK: - UISearchResultsUpdating Delegate
    
    func updateSearchResults(for searchController: UISearchController) {
        //print("update to '\(searchController.searchBar.text ?? "")' filtering: \(isFiltering() ? "true" : "false")")
        updateUI()
    }
    
    private func searchBarIsEmpty() -> Bool {
        // Returns true if the text is empty or nil
        return searchController.searchBar.text?.isEmpty ?? true
    }
    
    private func isFiltering() -> Bool {
        return searchController.isActive && !searchBarIsEmpty()
    }

    // MARK: - MusicObserverDelegate
    
    func nowPlayingItemDidChange(to item: MPMediaItem?) {
        DispatchQueue.main.async {
            NSLog("ArtistsVC now playing item is '\(item?.title ?? "<sine nomine>")'")
            self.musicViewController?.nowPlayingItemDidChange(to: item)
        }
    }
    
    func playbackStateDidChange(to state: MPMusicPlaybackState) {
        DispatchQueue.main.async {
            self.musicViewController?.playbackStateDidChange(to: state)
        }
    }
}

