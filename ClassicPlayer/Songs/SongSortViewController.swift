//
//  SongSortViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/31/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import MediaPlayer


enum SongSorts: Int {
    case title
    case artist
    
    var dropDownDisplayName: String {
        get {
            switch self {
            case .title:
                return "Title"
           case .artist:
                return "Artist"
            }
        }
    }
    
    var sortDescriptor: String {
        get {
            switch self {
            case .title:
                return "title"
            case .artist:
                return "artist"
            }
        }
    }

    func sortField(from song: Song) -> String {
        switch self {
        case .title:
            return song.title ?? ""
        case .artist:
            return song.artist ?? ""
        }
    }
}

class SongSortViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    weak var songsViewController: SongsViewController?
    @IBOutlet weak var tableView: UITableView!
    

    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
   }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    // MARK: - UITableViewDataSource
    
    func numberOfSections(in collectionView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4 //because there is no way to get the number of enum values
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Sorting", for: indexPath)
        cell.textLabel?.text = SongSorts(rawValue: indexPath.row)?.dropDownDisplayName
        cell.textLabel?.textColor = AppDelegate.brandColor
        return cell
    }

    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let newSort = SongSorts(rawValue: indexPath.row) {
            songsViewController?.userDidChoose(sort: newSort)
        }
    }
}
