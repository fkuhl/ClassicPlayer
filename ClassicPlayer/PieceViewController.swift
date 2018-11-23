//
//  PieceViewController.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 12/26/17.
//  Copyright © 2017 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

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

class PieceViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    static let enSpace = "\u{2002}"
    static let blackCircle = "\u{25CF}"
    private let myControllerID = Bundle.main.bundleIdentifier! + ".PieceViewController"
    private var observingContext = Bundle.main.bundleIdentifier! + ".PieceViewController"
    private var rateObserver = RateObserver()
    private let indexObserver = IndexObserver()
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var composer: UILabel!
    @IBOutlet weak var pieceTitle: UILabel!
    @IBOutlet weak var artist: UILabel!
    @IBOutlet weak var movementTable: UITableView!
    weak var playerViewController: AVPlayerViewController?
    weak var selectedPiece: Piece?
    var movements: NSOrderedSet?
    var firstTableIndexInPlayer = 0    //index of first movement in player
//    var playerRate: Float = 0.0
 
    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.rateObserver = RateObserver()
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
        print("PieceVC.viewWillAppear: \(self) player: \(appDelegate.player)")
        self.title = selectedPiece?.title
        self.composer.text = selectedPiece?.composer
        self.pieceTitle.text = selectedPiece?.title
        self.artist.text = selectedPiece?.artist
        self.movements = selectedPiece?.movements
        let id = selectedPiece?.albumID
        if let realID = id {
            self.artwork.image = AppDelegate.artworkFor(album: realID)
        }
        //Priority lowered on artwork height to prevent unsatisfiable constraint.
        adjustStack()
        if (selectedPiece?.movements) != nil && (selectedPiece?.movements)!.count > 0 {
            movementTable?.isHidden = false
        } else {
            movementTable?.isHidden = true
        }
        print("player ID '\(appDelegate.player.settingController)' active: \(appDelegate.player.isActive) " +
            "current table index: \(appDelegate.player.type == .queue ? String(appDelegate.player.currentTableIndex) : "single") ")
        playerViewController?.player = appDelegate.player.player
        if appDelegate.player.isActive {
            if appDelegate.player.settingController == myControllerID {
                indexObserver.start(on: self)
                rateObserver.start(on: self)
            }
        } else {
            installPlayer()   //fresh player
        }
        movementTable.reloadData()
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

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return movements?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Movement", for: indexPath) as! MovementTableViewCell
        if appDelegate.player.settingController == myControllerID {
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
        let movementEntry = movements![indexPath.row]
        cell.movementTitle.text = (movementEntry as? Movement)?.title
        cell.duration.text = (movementEntry as? Movement)?.duration
        return cell
    }
 
    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        firstTableIndexInPlayer = indexPath.row
        let partialList = (selectedPiece?.movements)!.array[indexPath.row...]
        let playerItems = partialList.map {
            (movementAny: Any) -> AVPlayerItem in
            let item = AVPlayerItem(url: ((movementAny as? Movement)?.trackURL)!)
            return item
        }
        indexObserver.stop(on: self)
        rateObserver.stop(on: self)
        setQueuePlayer(items: playerItems, tableIndex: firstTableIndexInPlayer)
        tableView.reloadData()
        playerViewController?.player?.play() //Tap on the table, it starts to play
    }

    // MARK: - Player management

    private func setQueuePlayer(items: [AVPlayerItem], tableIndex: Int) {
        playerViewController?.player = appDelegate.player.setPlayer(items: items,
                                                                    tableIndex: tableIndex,
                                                                    settingController: myControllerID)
        indexObserver.start(on: self)
        rateObserver.start(on: self)
        if items.count == 1 {
            playerViewController?.player?.actionAtItemEnd = .pause
        }
    }
    
    //The embed segue that places the AVPlayerViewController in the ContainerVC
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PlayTracks" {
            //print("PieceVC.prepareForSegue. playerVC: \(segue.destination)")
            self.playerViewController = segue.destination as? AVPlayerViewController
        }
    }
    
    private func installPlayer() {
        if (selectedPiece?.movements) != nil && (selectedPiece?.movements)!.count > 0 {
            let movements = (selectedPiece?.movements)!.array
            let playerItems = movements.map {
                movementAny in
                return AVPlayerItem(url: ((movementAny as? Movement)?.trackURL)!)
            }
            firstTableIndexInPlayer = 0 //start with all movements
            setQueuePlayer(items: playerItems, tableIndex: 0)
        } else {
            playerViewController?.player = appDelegate.player.setPlayer(url: (selectedPiece?.trackURL)!,
                                                                        settingController: myControllerID)
            rateObserver.start(on: self)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(Player.currentPlayerIndex) {
            if let currentItemIndex = change?[.newKey] as? Int {
                print("new currentItemIndex, index \(currentItemIndex)")
//                if currentlyPlayingIndex == movements!.count - 1 {
//                    //Just pause after last item, rather than searching for stuff.
//                    //.advance makes the player spin; .none makes the player sit there.
//                    (object as? AVPlayer)?.actionAtItemEnd = .pause
//                    NotificationCenter.default.addObserver(
//                        self,
//                        selector: #selector(self.pieceFinished),
//                        name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
//                        object: nil)
//                }
                DispatchQueue.main.async { self.movementTable.reloadData() }
                //As of iOS 11, the scroll seems to need a little delay.
                let deadlineTime = DispatchTime.now() + .milliseconds(100)
                DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                    if let visibleIndexPaths = self.movementTable.indexPathsForVisibleRows {
                        let currentPath = IndexPath(indexes: [0, self.appDelegate.player.currentTableIndex])
                        if !visibleIndexPaths.contains(currentPath) {
                            self.movementTable.scrollToRow(at: currentPath, at: .bottom, animated: true)
                        }
                    }
                }
            }
        }
        if keyPath == #keyPath(AVPlayer.rate) {
            if let rate = change?[.newKey] as? NSNumber {
                print("player rate: \(rate.floatValue)")
                DispatchQueue.main.async { self.movementTable.reloadData() }
            }
        }
    }
    
}
