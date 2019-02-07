//
//  SelectedPiecesViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 12/26/17.
//  Copyright © 2017 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import CoreData
import MediaPlayer

class PieceTableViewCell: UITableViewCell {
    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var pieceTitle: UILabel!
    @IBOutlet weak var pieceArtist: UILabel!
}

class SelectedPiecesViewController: UIViewController, NSFetchedResultsControllerDelegate, UITableViewDelegate, UITableViewDataSource, MusicObserverDelegate {
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private static let indexedSectionCount = 27  //A magic number; that's how many sections any UITableView index can have.
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var playerViewHeight: NSLayoutConstraint!
    var selectionValue: String?
    var selectionField: String?
    var displayTitle:   String?
    private var tableIsLoaded = false
    private var pieces: [Piece]?
    private var sectionCount = 1
    private var sectionSize = 0
    private var sectionTitles: [String]?
    weak var musicViewController: MusicViewController?
    private var musicObserver = MusicObserver()
    weak var playingPiece: Piece?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 72.0
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fontSizeChanged),
                                               name: UIContentSizeCategory.didChangeNotification,
                                               object: nil)
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
        if !tableIsLoaded {
            updateUI()
            tableIsLoaded = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        musicObserver.stop()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    private func updateUI() {
        self.title = displayTitle
        let context:NSManagedObjectContext! = (UIApplication.shared.delegate as! AppDelegate).mainThreadContext
        let request = NSFetchRequest<Piece>()
        request.entity = NSEntityDescription.entity(forEntityName: "Piece", in: context)
        request.predicate = NSPredicate(format: "%K == %@", selectionField!, selectionValue!)
        request.resultType = .managedObjectResultType
        request.returnsDistinctResults = true
        //request.sortDescriptors = [ NSSortDescriptor(key: "title", ascending: true) ]
        do {
            pieces = try context.fetch(request)
            pieces?.sort(by: titlePredicate)
            computeSections()
            tableView.reloadData()
//            if pieces?.count == 1 && !appDelegate.player.isActive {
//                playerLabel?.text = "no piece selected"
//                playerViewController?.contentOverlayView?.setNeedsDisplay()
//           }
        }
        catch {
            let error = error as NSError
            let message = "\(String(describing: error.userInfo))"
            NSLog("error retrieving selected pieces: \(error), \(error.userInfo)")
            let alert = UIAlertController(title: "Error Retrieving Selected Pieces", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Exit App", style: .default, handler: { _ in
                exit(1)
            }))
            self.present(alert, animated: true)
        }
    }

    private func computeSections() {
        guard pieces != nil else {
            sectionCount = 1
            sectionSize = 0
            return
        }
        if presentAsOneSection() {
            sectionCount = 1
            sectionSize = pieces!.count
            sectionTitles = []
            return
        }
        sectionCount = SelectedPiecesViewController.indexedSectionCount
        sectionSize = pieces!.count / SelectedPiecesViewController.indexedSectionCount
        sectionTitles = []
        for i in 0 ..< SelectedPiecesViewController.indexedSectionCount {
            let piece = pieces![i * sectionSize]
            let entry = removeArticle(from: piece.title ?? "") //section titles reflect anarthrous ordering
            let title = entry.prefix(2)
            //print("title \(i) is \(title ?? "nada")")
            sectionTitles?.append(String(title))
        }
    }
    
    private func presentAsOneSection() -> Bool {
        return (pieces?.count ?? 0) < SelectedPiecesViewController.indexedSectionCount * 2
    }

    @objc private func fontSizeChanged() {
        DispatchQueue.main.async {
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionCount
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if sectionCount == 1 {
            return pieces?.count ?? 0
        }
        if section < SelectedPiecesViewController.indexedSectionCount - 1 {
            return sectionSize
        } else {
            //that pesky last section
            return pieces!.count - SelectedPiecesViewController.indexedSectionCount * sectionSize
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Piece", for: indexPath) as! PieceTableViewCell
        let pieceIndex = indexPath.section * sectionSize + indexPath.row //works even if 1 section
        let pieceEntry = pieces![pieceIndex]
        cell.pieceTitle?.text = pieceEntry.title
        cell.pieceArtist?.text = pieceEntry.artist
        let id = pieceEntry.albumID
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
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sectionTitles
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            musicViewController = segue.destination as? MusicViewController
        }
        if segue.identifier == "PieceSelected" {
            let secondViewController = segue.destination as! PieceViewController
            if let selected = tableView?.indexPathForSelectedRow {
                secondViewController.selectedPiece = pieces![selected.section * sectionSize + selected.row]
            }
        }
    }

    // MARK: - MusicObserverDelegate
    
    func nowPlayingItemDidChange(to item: MPMediaItem?) {
        DispatchQueue.main.async {
            NSLog("SelectedPiecesVC now playing item is '\(item?.title ?? "<sine nomine>")'")
            self.musicViewController?.nowPlayingItemDidChange(to: item)
        }
    }
    
    func playbackStateDidChange(to state: MPMusicPlaybackState) {
        DispatchQueue.main.async {
            self.musicViewController?.playbackStateDidChange(to: state)
        }
    }
}

fileprivate func titlePredicate(a: Piece, b: Piece) -> Bool {
    let aTitle = a.title ?? ""
    let bTitle = b.title ?? ""
    return aTitle.anarthrousCompare(bTitle) == .orderedAscending
}
