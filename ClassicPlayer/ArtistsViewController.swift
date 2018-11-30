//
//  ArtistsViewController
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 2/13/2018.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import MediaPlayer
import AVFoundation
import AVKit

class ArtistsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating {
    @IBOutlet weak var tableView: UITableView!
    let searchController = UISearchController(searchResultsController: nil)
    private var tableIsLoaded = false
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    private static var indexedSectionCount = 27  //A magic number; that's how many sections any UITableView index can have.
    private var artistObjects: [MPMediaItem]?
    private var sectionCount = 1
    private var sectionSize = 0
    private var sectionTitles: [String]?
    weak var playerViewController: AVPlayerViewController?
    weak var playerLabel: UILabel?

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
        playerViewController?.player = appDelegate.player.player
        playerLabel?.text = appDelegate.player.label
        updateUI()
    }
    
    private func updateUI() {
        let query = MPMediaQuery.artists()
        artistObjects = []
        for collection in query.collections! {
            let possibleItem = collection.items.first
            if let item = possibleItem {
                if isFiltering(), let artist = item.artist {
                    if artist.localizedCaseInsensitiveContains(searchController.searchBar.text!) {
                        artistObjects!.append(item)
                    }
                } else {
                    artistObjects!.append(item)
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
        guard artistObjects != nil else {
            sectionCount = 1
            sectionSize = 0
            return
        }
        if presentAsOneSection() {
            sectionCount = 1
            sectionSize = artistObjects!.count
            sectionTitles = []
            return
        }
            if artistObjects!.count < ArtistsViewController.indexedSectionCount {
                sectionCount = 1
                sectionSize = artistObjects!.count
                sectionTitles = []
            } else {
                sectionCount = ArtistsViewController.indexedSectionCount
                sectionSize = artistObjects!.count / ArtistsViewController.indexedSectionCount
                sectionTitles = []
                for i in 0 ..< ArtistsViewController.indexedSectionCount {
                    let item = artistObjects![i * sectionSize]
                    let artist = item.artist
                    let title = artist?.prefix(2)
                    //print("title \(i) is \(title ?? "nada")")
                    sectionTitles?.append(String(title!))
                }
            }
    }
    
    private func presentAsOneSection() -> Bool {
        if artistObjects == nil { return true }
        return artistObjects!.count < ArtistsViewController.indexedSectionCount * 2
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
            return artistObjects!.count - ArtistsViewController.indexedSectionCount * sectionSize
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Artist", for: indexPath)
        let artistEntry = artistObjects![indexPath.section * sectionSize + indexPath.row]
        cell.textLabel?.text = artistEntry.artist
        return cell
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sectionTitles
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            print("ArtistsVC.prepareForSegue. playerVC: \(segue.destination)")
            playerViewController = segue.destination as? AVPlayerViewController
            //This installs the UILabel. After this, we just change the text.
            playerLabel = add(label: "not init", to: playerViewController!)
        }
        if segue.identifier == "ArtistSelected" {
            let secondViewController = segue.destination as! SelectedPiecesViewController
            if let selected = tableView?.indexPathForSelectedRow {
                secondViewController.selectionField = "artistID"
                let selectedArtist = artistObjects![selected.section * sectionSize + selected.row]
                let artistID = selectedArtist.artistPersistentID
                secondViewController.selectionValue = AppDelegate.encodeForCoreData(id: artistID)
                secondViewController.displayTitle = selectedArtist.artist
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
}

