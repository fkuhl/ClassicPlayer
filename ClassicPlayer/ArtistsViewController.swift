//
//  ArtistsViewController
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 2/13/2018.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import MediaPlayer

class ArtistsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    private var tableIsLoaded = false
    
    private static var indexedSectionCount = 27  //A magic number; that's how many sections any UITableView index can have.
    private var artistObjects: [MPMediaItem]?
    private var sectionCount = 1
    private var sectionSize = 0
    private var sectionTitles: [String]?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.rowHeight = UITableViewAutomaticDimension //Autolayout determines height!
        self.tableView.estimatedRowHeight = 64.0
        loadArtists()
        computeSections()
    }
    
    private func loadArtists() {
        let query = MPMediaQuery.artists()
        artistObjects = []
        for collection in query.collections! {
            let possibleItem = collection.items.first
            if let item = possibleItem {
                artistObjects?.append(item)
            }
        }
        //TODO sort artists
        print("found \(query.collections!.count) artists")
    }
    
    private func computeSections() {
        if let artists = artistObjects {
            if artists.count < ArtistsViewController.indexedSectionCount {
                sectionCount = 1
                sectionSize = artists.count
                sectionTitles = []
            } else {
                sectionCount = ArtistsViewController.indexedSectionCount
                sectionSize = artists.count / ArtistsViewController.indexedSectionCount
                sectionTitles = []
                for i in 0 ..< ArtistsViewController.indexedSectionCount {
                    let item = artists[i * sectionSize]
                    let artist = item.artist
                    let title = artist?.prefix(2)
                    //print("title \(i) is \(title ?? "nada")")
                    sectionTitles?.append(String(title!))
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        cell.textLabel?.text = artistEntry.albumArtist
        return cell
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sectionTitles
    }
    
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        if segue.identifier == "ComposerSelected" {
//            let secondViewController = segue.destination as! PiecesFromComposerViewController
//            if let selected = tableView?.indexPathForSelectedRow {
//                secondViewController.selectedComposer =
//                    artistObjects![selected.section * sectionSize + selected.row]["artist"] as? String
//            }
//        }
//    }
}

