//
//  AlbumTracksViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/27/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import MediaPlayer

class TrackTableViewCell: UITableViewCell {
    @IBOutlet weak var indicator: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var duration: UILabel!
}

class AlbumTracksViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private var observingContext = Bundle.main.bundleIdentifier! + ".AlbumTracksViewController"
    private var rateObserver = RateObserver()
    private let indexObserver = IndexObserver()
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    weak var album: Album? {
        didSet {
            loadTracks() //Must be performed before segue to install player!
        }
    }
    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var composer: UILabel!
    @IBOutlet weak var albumTitle: UILabel!
    @IBOutlet weak var artist: UILabel!
    @IBOutlet weak var trackTable: UITableView!
    @IBOutlet weak var year: UILabel!
    @IBOutlet weak var tracks: UILabel!
    weak var playerViewController: AVPlayerViewController?
    var trackData: [MPMediaItem]?
    weak var playerLabel: UILabel?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        trackTable.delegate = self
        trackTable.dataSource = self
        trackTable.rowHeight = UITableView.automaticDimension
        trackTable.estimatedRowHeight = 64.0
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fontSizeChanged),
                                               name: UIContentSizeCategory.didChangeNotification,
                                               object: nil)
    }
    
    private func add(asChildViewController viewController: UIViewController) {
        // Add Child View Controller
        addChild(viewController)
        
        // Add Child View as Subview
        view.addSubview(viewController.view)
        
        // Configure Child View
        viewController.view.frame = view.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Notify Child View Controller
        viewController.didMove(toParent: self)
    }
    
    private func loadTracks() {
        let query = MPMediaQuery.songs()
        let idVal = AppDelegate.decodeIDFrom(coreDataRepresentation: (album?.albumID!)!)
        let predicate = MPMediaPropertyPredicate(value: idVal, forProperty: MPMediaItemPropertyAlbumPersistentID)
        query.filterPredicates = Set([ predicate ])
        trackData = []
        for collection in query.collections! {
            let possibleItem = collection.items.first
            if let item = possibleItem {
                if item.assetURL != nil { trackData?.append(item) } //iTunes LPs have nil URLs!!
            }
        }
        print("AlbumTracksVC loaded \(trackData?.count ?? -1) tracks")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("AlbumTracksVC will appear")
        let id = album?.albumID
        if let realID = id {
            self.artwork.image = AppDelegate.artworkFor(album: realID)
         }
        composer.text = album?.composer ?? "[]"
        albumTitle.text = album?.title
        artist.text = album?.artist
        let yearText: String
        if let year = album?.year {
            yearText = year > 0 ? "\(year)" : "[n.d.]"
        } else {
            yearText = "[n.d.]"
        }
        year?.text = "\(yearText) • \(album?.genre ?? "")"
        tracks?.text = "tracks: \(/*album?.trackCount ?? 0*/ trackData!.count)"
        //Priority lowered on artwork height to prevent unsatisfiable constraint.
        adjustStack()
        print("player ID \(appDelegate.player.setterID) active: \(appDelegate.player.isActive) " +
            "current table index: \(appDelegate.player.type == .queue ? String(appDelegate.player.currentTableIndex) : "single") ")
        playerViewController?.player = appDelegate.player.player
        if appDelegate.player.isActive {
            if appDelegate.player.setterID == mySetterID() {
                indexObserver.start(on: self)
                rateObserver.start(on: self)
            }
            playerLabel?.text = appDelegate.player.label
        } else {
            installPlayer()   //fresh player
        }
        trackTable.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        indexObserver.stop(on: self)
        rateObserver.stop(on: self)
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

    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return trackData?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Track", for: indexPath) as! TrackTableViewCell
        if appDelegate.player.setterID == mySetterID() {
            if indexPath.row == appDelegate.player.currentTableIndex {
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
        let trackEntry = trackData![indexPath.row]
        cell.title.text = trackEntry.title
        cell.duration.text = AppDelegate.durationAsString(trackEntry.playbackDuration)
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let partialList = trackData![indexPath.row...]
        let playerItems: [AVPlayerItem] = partialList.map {
            item in
            return AVPlayerItem(url: item.assetURL!)
        }
        indexObserver.stop(on: self)
        rateObserver.stop(on: self)
        setQueuePlayer(items: playerItems, startingIndex: indexPath.row)
        playerViewController?.player?.play() //Tap on the table, it starts to play
        playerLabel?.text = labelForPlayer(atIndex: indexPath.row)
        playerViewController?.contentOverlayView?.setNeedsDisplay()
        tableView.reloadData()
    }
    
    private func labelForPlayer(atIndex: Int) -> String {
        let composer = trackData![atIndex].composer
        let artist = trackData![atIndex].artist
        let title = trackData![atIndex].title
        if let uComposer = composer {
            return uComposer + ": " + (title ?? "")
        } else if let uArtist = artist {
            return uArtist + ": " + (title ?? "")
        } else {
            return title ?? ""
        }
    }
    
    private func mySetterID() -> String {
        return Bundle.main.bundleIdentifier! + ".AlbumTracksViewController"
            + "." + (album?.title ?? "")
    }

    // MARK: - Player management

    private func setQueuePlayer(items: [AVPlayerItem], startingIndex: Int) {
        let newLabel = labelForPlayer(atIndex: startingIndex)
        playerViewController?.player = appDelegate.player.setPlayer(items: items,
                                                                    tableIndex: startingIndex,
                                                                    setterID: mySetterID(),
                                                                    label: newLabel)
        playerLabel?.text = newLabel
        indexObserver.start(on: self)
        rateObserver.start(on: self)
        if items.count == 1 {
            playerViewController?.player?.actionAtItemEnd = .pause
        }
    }
    
    //The embed segue that places the AVPlayerViewController in the ContainerVC
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            print("AlbumTracksVC.prepareForSegue")
            playerViewController = segue.destination as? AVPlayerViewController
            //This installs the UILabel. After this, we just change the text.
            playerLabel = ClassicPlayer.add(label: "not init", to: playerViewController!)
        }
    }

    private func installPlayer() {
        if trackData != nil && trackData!.count > 0 {
            let playerItems: [AVPlayerItem] = trackData!.map {
                item in
                return AVPlayerItem(url: item.assetURL!)
            }
            setQueuePlayer(items: playerItems, startingIndex: 0)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(Player.currentPlayerIndex) {
            if let currentItemIndex = change?[.newKey] as? Int {
                print("new currentItem, index \(currentItemIndex)")
                DispatchQueue.main.async {
                    self.playerLabel?.text = self.labelForPlayer(atIndex: self.appDelegate.player.currentTableIndex)
                    self.playerViewController?.contentOverlayView?.setNeedsDisplay()
                    self.trackTable.reloadData()
                }
                //As of iOS 11, the scroll seems to need a little delay.
                let deadlineTime = DispatchTime.now() + .milliseconds(100)
                DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                    if let visibleIndexPaths = self.trackTable.indexPathsForVisibleRows {
                        let currentPath = IndexPath(indexes: [0, self.appDelegate.player.currentTableIndex])
                        if !visibleIndexPaths.contains(currentPath) {
                            self.trackTable.scrollToRow(at: currentPath, at: .bottom, animated: true)
                        }
                    }
                }
            }
        }
        if keyPath == #keyPath(AVPlayer.rate) {
            if let rate = change?[.newKey] as? NSNumber {
                print("player rate: \(rate.floatValue)")
                DispatchQueue.main.async { self.trackTable.reloadData() }
            }
        }
    }

}
