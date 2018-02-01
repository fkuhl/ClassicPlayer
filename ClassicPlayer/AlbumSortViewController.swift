//
//  AlbumSortViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/31/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit


enum AlbumSorts: Int {
    case title
    case composer
    case artist
    case genre
    
    var dropDownDisplayName: String {
        get {
            switch self {
            case .title:
                return "Title"
            case.composer:
                return "Composer"
           case .artist:
                return "Artist"
            case .genre:
                return "Genre"
            }
        }
    }
    
    var sortDescriptor: String {
        get {
            switch self {
            case .title:
                return "title"
            case .composer:
                return "composer"
            case .artist:
                return "artist"
            case .genre:
                return "genre"
            }
        }
    }
}

class AlbumSortViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    weak var albumsViewController: AlbumsViewController?
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
        cell.textLabel?.text = AlbumSorts(rawValue: indexPath.row)?.dropDownDisplayName
        cell.textLabel?.textColor = AppDelegate.brandColor
        return cell
    }

    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let newSort = AlbumSorts(rawValue: indexPath.row) {
            albumsViewController?.userDidChoose(sort: newSort)
        }
    }
}
