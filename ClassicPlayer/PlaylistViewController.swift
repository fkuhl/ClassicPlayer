//
//  PlaylistViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/27/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import MediaPlayer

//This VC uses SongTableViewCell

class PlaylistViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    weak var playlist: MPMediaPlaylist? {
        didSet {
            //Copy the playlist items to avoid obscure memory problem
            trackData = Array(playlist!.items)
        }
    }
    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var labelsStack: UIStackView!
    @IBOutlet weak var playlistName: UILabel!
    @IBOutlet weak var descriptionText: UILabel!
    @IBOutlet weak var trackTable: UITableView!
    var trackData: [MPMediaItem]?
    var playerViewController: AVPlayerViewController?
    weak var playerLabel: UILabel?
    private let indexObserver = IndexObserver()
    private var rateObserver = RateObserver()
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        playlistName?.text = playlist!.name
        descriptionText?.text = playlist!.descriptionText
        let id = playlist!.representativeItem?.albumPersistentID
        if let realID = id {
            //Someday we might elaborate the displayed artwork
            artwork?.image = AppDelegate.artworkFor(album: realID)
        }
       adjustStack()
        playerViewController?.player = appDelegate.player.player
        if appDelegate.player.isActive {
            if appDelegate.player.setterID == mySetterID() {
                indexObserver.start(on: self)
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "Track", for: indexPath) as! SongTableViewCell
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
                cell.artwork.isOpaque = false
                cell.artwork.alpha = 0.5
            } else {
                cell.indicator.stopAnimating()
                cell.indicator.animationImages = nil
                cell.indicator.image = appDelegate.audioNotCurrent
                cell.artwork.isOpaque = true
                cell.artwork.alpha = 1.0
            }
        } else {
            //If it's not our player, show no audio indicators
            cell.indicator.stopAnimating()
            cell.indicator.animationImages = nil
            cell.indicator.image = appDelegate.audioNotCurrent
        }
        let trackEntry = trackData![indexPath.row]
        let id = trackEntry.albumPersistentID
        cell.artwork.image = AppDelegate.artworkFor(album: id)
        cell.title.text = trackEntry.title
        cell.artist.text = trackEntry.artist
        cell.duration.text = AppDelegate.durationAsString(trackEntry.playbackDuration)
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
        let partialList = trackData![indexPath.row...]
        let playerItems: [AVPlayerItem] = partialList.map {
            item in
            return AVPlayerItem(url: item.assetURL!)
        }
        indexObserver.stop(on: self)
        rateObserver.stop(on: self)
        setQueuePlayer(items: playerItems,
                       tableIndex: indexPath.row)
//        if appDelegate.player.currentPlayerIndex == trackData!.count - 1 {
//            //Just pause after last item, rather than searching for stuff.
//            playerViewController?.player?.actionAtItemEnd = .pause
//        }
        tableView.reloadData()
        playerViewController?.player?.play() //Tap on the table, it starts to play
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
        return Bundle.main.bundleIdentifier! + ".PlaylistViewController" +
            ">" + AppDelegate.encodeForCoreData(id: playlist!.persistentID) 
    }

    // MARK: - Player management

    private func setQueuePlayer(items: [AVPlayerItem], tableIndex: Int) {
        let newLabel = labelForPlayer(atIndex: tableIndex)
        playerViewController?.player = appDelegate.player.setPlayer(items: items,
                                                                    tableIndex: tableIndex,
                                                                    setterID: mySetterID(),
                                                                    label: newLabel)
        playerLabel?.text = newLabel
        playerViewController?.contentOverlayView?.setNeedsDisplay()
        indexObserver.start(on: self)
        rateObserver.start(on: self)
        if items.count == 1 {
            playerViewController?.player?.actionAtItemEnd = .pause
        }
    }
    
    //The embed segue that places the AVPlayerViewController in the ContainerVC
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            self.playerViewController = segue.destination as? AVPlayerViewController
            //This installs the UILabel. After this, we just change the text.
            playerLabel = ClassicPlayer.add(label: "not init", to: playerViewController!)
        }
    }

    private func installPlayer(forIndex: Int) {
        if trackData != nil && trackData!.count > 0 {
            let playerItems: [AVPlayerItem] = trackData!.map {
                item in
                return AVPlayerItem(url: item.assetURL!)
            }
            setQueuePlayer(items: playerItems, tableIndex: 0)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(Player.currentPlayerIndex) {
            if let currentPlayerIndex = change?[.newKey] as? Int {
                print("new currentPlayerIndex: \(currentPlayerIndex), table index: \(appDelegate.player.currentTableIndex)")
                DispatchQueue.main.async { self.trackTable.reloadData() }
                //As of iOS 11, the scroll seems to need a little delay.
                let deadlineTime = DispatchTime.now() + .milliseconds(100)
                DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                    if let visibleIndexPaths = self.trackTable.indexPathsForVisibleRows {
                        let currentPath = IndexPath(indexes: [0, self.appDelegate.player.currentTableIndex])
                        //print("visIP: \(visibleIndexPaths) currP: \(currentPath)")
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
