//
//  PieceViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 12/26/17.
//  Copyright © 2017 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import MediaPlayer

class MovementTableViewCell: UITableViewCell {
    @IBOutlet weak var movementTitle: UILabel!
    @IBOutlet weak var indicator: UIImageView!
    @IBOutlet weak var duration: UILabel!
}

/*
 To avoid the dread "Detected a case where constraints ambiguously suggest a height of zero"
 complaint regarding table view cell heights, the trick is to ensure that the contents are
 constrained to ALL 4 EDGES. The StackView does the trick here.
 */

class PieceViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MusicObserverDelegate {
    static let enSpace = "\u{2002}"
    static let blackCircle = "\u{25CF}"
    private var musicObserver = MusicObserver()
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var composer: UILabel!
    @IBOutlet weak var pieceTitle: UILabel!
    @IBOutlet weak var artist: UILabel!
    @IBOutlet weak var movementTable: UITableView!
    weak var musicViewController: MusicViewController?
    weak var selectedPiece: Piece?
    weak var playerLabel: UILabel?
    //var movements: NSOrderedSet?
    var hasMultipleMovements = true
 
    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.movementTable.delegate = self
        self.movementTable.dataSource = self
        self.movementTable.rowHeight = UITableView.automaticDimension
        self.movementTable.estimatedRowHeight = 64.0
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fontSizeChanged),
                                               name: UIContentSizeCategory.didChangeNotification,
                                               object: nil)
   }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.title = selectedPiece?.title
        self.composer.text = selectedPiece?.composer
        self.pieceTitle.text = selectedPiece?.title
        self.artist.text = selectedPiece?.artist
        let id = selectedPiece?.albumID
        if let realID = id {
            self.artwork.image = AppDelegate.artworkFor(album: realID)
        }
        //Priority lowered on artwork height to prevent unsatisfiable constraint.
        adjustStack()
        hasMultipleMovements = (selectedPiece?.movements) != nil && (selectedPiece?.movements)!.count > 0
        if hasMultipleMovements {
            movementTable?.isHidden = false
        } else {
            movementTable?.isHidden = true
        }
        NSLog("PieceVC.vWA player ID '\(appDelegate.musicPlayer.setterID)' "
            + "player is playing: \(musicPlayerPlaybackState() == .playing) " +
            "current table index: \(appDelegate.musicPlayer.currentTableIndexAsString) ")
        if musicPlayerPlaybackState() == .playing {
            musicViewController?.nowPlayingItemDidChange(to: MPMusicPlayerController.applicationMusicPlayer.nowPlayingItem)
            musicObserver.start(on: self)
//            if appDelegate.player.setterID == mySetterID() {
//                scrollToCurrent()
//            }
        } else {
            installPlayerForAllMovements()   //fresh player
        }
        movementTable.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        musicObserver.stop()
    }
    
    @objc private func fontSizeChanged() {
        DispatchQueue.main.async {
            self.adjustStack()
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }
    
    private func adjustStack() {
        if UIApplication.shared.preferredContentSizeCategory > .extraExtraLarge {
            self.artAndLabelsStack.axis = .vertical
            self.artAndLabelsStack.alignment = .leading
        } else {
            self.artAndLabelsStack.axis = .horizontal
            self.artAndLabelsStack.alignment = .top
            //Content hugging priority lowered on text fields so they expand across the cell.
            self.artAndLabelsStack.distribution = .fill
        }
    }

    @IBAction func stackWasTapped(_ sender: Any) {
        print("stack was tapped")
        if hasMultipleMovements { return }
        installPlayerForAllMovements()
    }
    
    @IBAction func artworkWasTapped(_ sender: Any) {
        NSLog("artwork was tapped")  //see prepareFor(segue:)
    }
    
    // MARK: - UITableViewDataSource

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return selectedPiece?.movements?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Movement", for: indexPath) as! MovementTableViewCell
        if appDelegate.musicPlayer.setterID == mySetterID() {
            if indexPath.row == appDelegate.musicPlayer.currentTableIndex {
                if musicPlayerPlaybackState() == .playing {
                    cell.indicator.image = nil
                    cell.indicator.animationImages = appDelegate.getAudioBarSet(for: view.traitCollection)
                    cell.indicator.animationRepeatCount = 0 //like, forever
                    cell.indicator.animationDuration = 0.6  //sec
                    cell.indicator.startAnimating()
                } else {
                    cell.indicator.stopAnimating()
                    cell.indicator.animationImages = nil
                    cell.indicator.image = appDelegate.getAudioPaused(for: view.traitCollection)
                }
            } else {
                cell.indicator.stopAnimating()
                cell.indicator.animationImages = nil
                cell.indicator.image = appDelegate.audioNotCurrent
            }
        } else {
            //If it's not our player, show no audio indicators
            cell.indicator.stopAnimating()
            cell.indicator.animationImages = nil
            cell.indicator.image = appDelegate.audioNotCurrent
        }
        if let movements = selectedPiece?.movements, movements.count > indexPath.row {
            let movementEntry = movements[indexPath.row]
            cell.movementTitle.text = (movementEntry as? Movement)?.title
            cell.duration.text = (movementEntry as? Movement)?.duration
        }
        return cell
    }
 
    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        setQueuePlayer(tableIndex: indexPath.row, paused: false)
        tableView.reloadData()
    }
    
    private func mySetterID() -> String {
        return Bundle.main.bundleIdentifier! + ".PiecesViewController"
            //Because piece title isn't guaranteed to be unique, hilarity might ensue.
            + "." + (selectedPiece?.title ?? "")
    }

    // MARK: - Player management

    private func setQueuePlayer(tableIndex: Int, paused: Bool) {
        let partialList = (selectedPiece?.movements)!.array[tableIndex...]
        let playerItems = partialList.compactMap(retrieveItem) //strips nils returned by transform!
        guard playerItems.count > 0 else {
            NSLog("PieceVC.setQueuePlayer had no items")
            return
        }
        musicObserver.stop()
        appDelegate.musicPlayer.setPlayer(items: playerItems,
                                          tableIndex: tableIndex,
                                          setterID: mySetterID(),
                                          paused: paused)
        musicViewController?.setInitialItem(item: playerItems[0])
        musicObserver.start(on: self)
    }

    private func setSinglePlayer(paused: Bool) {
        if let item = retrieveItem(from: selectedPiece) {
            musicObserver.stop()
            appDelegate.musicPlayer.setPlayer(item: item,
                                              setterID: mySetterID(),
                                              paused: paused)
            musicViewController?.setInitialItem(item: item)
            musicObserver.start(on: self)
        } else {
            NSLog("PieceVC.setSinglePlayer could not retrieve media item")
        }
    }

    private func retrieveItem(forMovement movementAny: Any) -> MPMediaItem? {
        var item: MPMediaItem?
        if let movement = movementAny as? Movement {
            let persistentID = ClassicalMediaLibrary.decodeIDFrom(coreDataRepresentation: movement.trackID!)
            let songQuery = MPMediaQuery.songs()
            let predicate = MPMediaPropertyPredicate(value: persistentID, forProperty: MPMediaItemPropertyPersistentID)
            songQuery.addFilterPredicate(predicate)
            if let returned = songQuery.items {
                if returned.count > 0 { item = returned[0] }
            }
        }
        return item
    }

    private func retrieveItem(from: Piece?) -> MPMediaItem? {
        var item: MPMediaItem?
        if let piece = from {
            let persistentID = ClassicalMediaLibrary.decodeIDFrom(coreDataRepresentation: piece.trackID!)
            let songQuery = MPMediaQuery.songs()
            let predicate = MPMediaPropertyPredicate(value: persistentID, forProperty: MPMediaItemPropertyPersistentID)
            songQuery.addFilterPredicate(predicate)
            if let returned = songQuery.items {
                if returned.count > 0 { item = returned[0] }
            }
        }
        return item
    }

    //The embed segue that places the AVPlayerViewController in the ContainerVC
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            //print("PieceVC.prepareForSegue. playerVC: \(segue.destination)")
            musicViewController = segue.destination as? MusicViewController
        }
        if segue.identifier == "ShowAlbum" {
            let secondViewController = segue.destination as! AlbumTracksViewController
            if let album = selectedPiece?.album {
                secondViewController.albumID = ClassicalMediaLibrary.decodeIDFrom(coreDataRepresentation: album.albumID!)
                secondViewController.title = album.title
            }
        }
    }
    
    private func installPlayerForAllMovements() {
        if hasMultipleMovements {
            setQueuePlayer(tableIndex: 0, paused: true) //start with all movements
         } else {
            setSinglePlayer(paused: false)
         }

    }

    // MARK: - MusicObserverDelegate
    
    func nowPlayingItemDidChange(to item: MPMediaItem?) {
        DispatchQueue.main.async {
            //NSLog("PieceVC now playing item is '\(item?.title ?? "<sine nomine>")'")
            self.musicViewController?.nowPlayingItemDidChange(to: item)
            if !self.hasMultipleMovements { return }
            self.movementTable.reloadData()
            self.scrollToCurrent()
       }
    }
    
    private func scrollToCurrent() {
        //As of iOS 11, the scroll seems to need a little delay.
        let deadlineTime = DispatchTime.now() + .milliseconds(100)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            if let visibleIndexPaths = self.movementTable.indexPathsForVisibleRows,
                let index = self.appDelegate.musicPlayer.currentTableIndex {
                let currentPath = IndexPath(indexes: [0, index])
                if !visibleIndexPaths.contains(currentPath) {
                    self.movementTable.scrollToRow(at: currentPath, at: .bottom, animated: true)
                }
            }
        }
    }
    
    func playbackStateDidChange(to state: MPMusicPlaybackState) {
        DispatchQueue.main.async {
            self.movementTable.reloadData()
            self.musicViewController?.playbackStateDidChange(to: state)
        }
    }

}
