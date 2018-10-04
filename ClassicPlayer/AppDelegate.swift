//
//  AppDelegate.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 12/16/17.
//  Copyright © 2017 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import CoreData
import MediaPlayer

extension Notification.Name {
    static let dataAvailable       = Notification.Name("com.tyndalesoft.ClassicPlayer.DataAvailable")
    static let libraryChanged      = Notification.Name("com.tyndalesoft.ClassicPlayer.LibraryChanged")
    static let clearingError       = Notification.Name("com.tyndalesoft.ClassicPlayer.ClearingError")
    static let initializingError   = Notification.Name("com.tyndalesoft.ClassicPlayer.InitializingError")
    static let loadingError        = Notification.Name("com.tyndalesoft.ClassicPlayer.LoadingError")
    static let savingError         = Notification.Name("com.tyndalesoft.ClassicPlayer.SavingError")
    static let storeError          = Notification.Name("com.tyndalesoft.ClassicPlayer.StoreError")
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private static let displayArtworkKey = "display_artwork_preference"
    /**
     Those genres which will be parsed for pieces and movements.
    */
    private static let parsedGenres = ["Classical", "Opera", "Church", "British", "Christmas"]
    private static let showParses = false
    private static let showPieces = false

    var window: UIWindow?
    var audioBarSet: [UIImage]?
    var audioPaused: UIImage?
    var audioNotCurrent: UIImage?
    
    private var libraryAlbumCount: Int32 = 0
    private var librarySongCount: Int32 = 0
    private var libraryPieceCount: Int32 = 0
    private var libraryMovementCount: Int32 = 0
    var mediaLibraryInfo: MediaLibraryInfo?

    // MARK: - App delegate

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }

    // MARK: - Audio and library

    private func initializeAudio() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            //In addition to setting this audio mode, info.plist contains a "Required background modes" key,
            //with an "audio" ("app plays audio ... AirPlay") entry.
            try audioSession.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default)
        } catch {
            let error = error as NSError
            NotificationCenter.default.post(Notification(name: .initializingError,
                                                         object: self,
                                                         userInfo: error.userInfo))
            NSLog("error setting category to AVAudioSessionCategoryPlayback: \(error), \(error.userInfo)")
        }
        makeAudioBarSet()
    }
    
    func checkLibraryChanged() {
        initializeAudio()
        let libraryInfos = getMediaLibraryInfo()
        if libraryInfos.count < 1 {
            NSLog("No app library found: load media lib to app")
            loadMediaLibraryToApp()
            return
        }
        mediaLibraryInfo = libraryInfos[0]
        if let storedLastModDate = mediaLibraryInfo!.lastModifiedDate {
            if MPMediaLibrary.default().lastModifiedDate <= storedLastModDate {
                //use current data
                NSLog("media lib stored \(MPMediaLibrary.default().lastModifiedDate), app lib stored \(storedLastModDate): use current app lib")
                logCurrentNumberOfAlbums()
                NotificationCenter.default.post(Notification(name: .dataAvailable))
                return
            }  else {
                NSLog("media lib stored \(MPMediaLibrary.default().lastModifiedDate), app lib data \(storedLastModDate): media lib changed, replace app lib")
                logCurrentNumberOfAlbums()
                NotificationCenter.default.post(Notification(name: .libraryChanged))
                return
            }
        } else {
            NotificationCenter.default.post(Notification(name: .initializingError,
                                                         object: self,
                                                         userInfo: ["message" : "Last modification date not set in media library info"]))
            NSLog("Last modification date not set in media library info")
        }
    }
    
    private func getMediaLibraryInfo() -> [MediaLibraryInfo] {
        let request = NSFetchRequest<MediaLibraryInfo>()
        request.entity = NSEntityDescription.entity(forEntityName: "MediaLibraryInfo", in: context)
        request.resultType = .managedObjectResultType
        do {
            return try context.fetch(request)
        } catch {
            let error = error as NSError
            NotificationCenter.default.post(Notification(name: .loadingError,
                                                         object: self,
                                                         userInfo: error.userInfo))
            NSLog("error retrieving media library info: \(error), \(error.userInfo)")
            return []
        }
    }
    
    private func logCurrentNumberOfAlbums() {
        let request = NSFetchRequest<Album>()
        request.entity = NSEntityDescription.entity(forEntityName: "Album", in: context)
        request.resultType = .managedObjectResultType
        do {
            let albums = try context.fetch(request)
            NSLog("\(albums.count) albums")
        } catch {
            let error = error as NSError
            NSLog("error retrieving album count: \(error), \(error.userInfo)")
        }
    }

    /**
     Load app from Media Library without clearing old data.
     Used by AppDelegate when there was no app library.
     
     - Precondition: App has authorization to access library
    */
    private func loadMediaLibraryToApp() {
        self.loadAppFromMediaLibrary(into: context)
        NotificationCenter.default.post(Notification(name: .dataAvailable))
    }

    /**
     Clear out old app library, and replace with media library contents.
     
     - Precondition: App has authorization to access library
     */
    func replaceAppLibraryWithMedia() {
        self.clearOldData(from: self.context)
        self.loadAppFromMediaLibrary(into: self.context)
        NotificationCenter.default.post(Notification(name: .dataAvailable))
    }
    
    private func clearOldData(from context: NSManagedObjectContext) {
        do {
            try clearEntities(ofType: "Movement", from: context)
            try clearEntities(ofType: "Piece", from: context)
            try clearEntities(ofType: "Album", from: context)
            try clearEntities(ofType: "Song", from: context)
            saveContext()
        } catch {
            let error = error as NSError
            NotificationCenter.default.post(Notification(name: .clearingError,
                                                         object: self,
                                                         userInfo: error.userInfo))
            NSLog("error clearing old data: \(error), \(error.userInfo)")
        }
    }

    private func clearEntities(ofType type: String, from context: NSManagedObjectContext) throws {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest<NSFetchRequestResult>()
        request.entity = NSEntityDescription.entity(forEntityName: type, in:context)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        request.predicate = NSPredicate(format: "title LIKE %@", ".*")
        deleteRequest.resultType = .resultTypeCount
        let deleteResult = try context.execute(deleteRequest) as? NSBatchDeleteResult
        NSLog("deleted \(deleteResult?.result ?? "<nil>") \(type)")
    }
    
    private func isGenreToParse(_ optionalGenre: String?) -> Bool {
        guard let genre = optionalGenre else {
            return false
        }
        return AppDelegate.parsedGenres.contains(genre)
    }
    
    private func loadAppFromMediaLibrary(into context: NSManagedObjectContext) {
        NSLog("started finding composers")
        findComposers()
        NSLog("finished finding composers")
        libraryAlbumCount = 0
        libraryPieceCount = 0
        librarySongCount = 0
        libraryMovementCount = 0
        let mediaAlbums = MPMediaQuery.albums()
        if mediaAlbums.collections == nil { return }
        for mediaAlbum in mediaAlbums.collections! {
            let mediaAlbumItems = mediaAlbum.items
            libraryAlbumCount += 1
            if AppDelegate.showPieces && isGenreToParse(mediaAlbumItems[0].genre) {
                print("Album: \(mediaAlbumItems[0].value(forProperty: MPMediaItemPropertyComposer) ?? "<anon>"): "
                    + "\(mediaAlbumItems[0].value(forProperty: MPMediaItemPropertyAlbumTrackCount) ?? "") "
                    + "\(mediaAlbumItems[0].value(forProperty: MPMediaItemPropertyAlbumTitle) ?? "<no title>")"
                    + " | \(mediaAlbumItems[0].value(forProperty: MPMediaItemPropertyAlbumArtist) ?? "<no artist>")"
                    + " | \((mediaAlbumItems[0].value(forProperty: "year") as? Int) ?? -1) ")
            }
            let appAlbum = makeAndFillAlbum(from: mediaAlbumItems, into: context)
            if isGenreToParse(appAlbum.genre) {
                loadPieces(for: appAlbum, from: mediaAlbumItems, into: context)
            } else {
                loadSongs(for: appAlbum, from: mediaAlbumItems, into: context)
            }
        }
        NSLog("found \(libraryAlbumCount) albums, \(libraryPieceCount) pieces, \(libraryMovementCount) movements, \(librarySongCount) tracks")
        storeMediaLibraryInfo()
    }
    
    private func makeAndFillAlbum(from mediaAlbumItems: [MPMediaItem],  into context: NSManagedObjectContext) -> Album {
        let album = NSEntityDescription.insertNewObject(forEntityName: "Album", into: context) as! Album
        //Someday we may purpose "artist" as a composite field containing ensemble, director, soloists
        album.artist = mediaAlbumItems[0].albumArtist
        album.title = mediaAlbumItems[0].albumTitle
        album.composer = mediaAlbumItems[0].composer
        album.genre = mediaAlbumItems[0].genre
        album.trackCount = Int32(mediaAlbumItems[0].albumTrackCount)
        album.albumID = AppDelegate.encodeForCoreData(id: mediaAlbumItems[0].albumPersistentID)
        album.year = mediaAlbumItems[0].value(forProperty: "year") as! Int32  //slightly undocumented!
        return album
    }
    
    private func storeMediaLibraryInfo() {
        var mediaInfoObject: MediaLibraryInfo
        let mediaLibraryInfosInStore = getMediaLibraryInfo()
        if mediaLibraryInfosInStore.count >= 1 {
            mediaInfoObject = mediaLibraryInfosInStore[0]
        } else {
            mediaInfoObject = NSEntityDescription.insertNewObject(forEntityName: "MediaLibraryInfo", into: context) as! MediaLibraryInfo
        }
        mediaInfoObject.lastModifiedDate = MPMediaLibrary.default().lastModifiedDate
        mediaInfoObject.albumCount = libraryAlbumCount
        mediaInfoObject.movementCount = libraryMovementCount
        mediaInfoObject.pieceCount = libraryPieceCount
        mediaInfoObject.songCount = librarySongCount
        saveContext()
        //NSLog("saved \(libraryAlbumCount) albums and \(libraryPieceCount) pieces for lib at \(mediaInfoObject.lastModifiedDate!)")
    }
    
    private func loadSongs(for album: Album, from collection: [MPMediaItem], into context: NSManagedObjectContext) {
        for mediaItem in collection {
            _ = storePiece(from: mediaItem, entitled: mediaItem.title ?? "", to: album, into: context)
        }
    }
    
    private enum LoadingState {
        case beginPiece
        case continuePiece
    }
    
    private func loadPieces(for album: Album, from collection: [MPMediaItem], into context: NSManagedObjectContext) {
        if collection.count < 1 { return }
//        if collection.count < 2 {
//            _ = storePiece(from: collection[0], entitled: collection[0].title ?? "", to: album, into: context)
//            return
//        }
        var state = LoadingState.beginPiece
        var i = 0
        var piece: Piece?
        var firstParse = ParseResult.undefined //compiler needs a default value
        var nextParse: ParseResult?
        repeat {
            let unwrappedTitle = collection[i].title ?? ""
            switch state {
            case .beginPiece:
                firstParse = bestParse(in: unwrappedTitle)
                if AppDelegate.showParses {
                    print("composer: '\(collection[i].composer ?? "")' raw: '\(unwrappedTitle)'")
                    print("   piece: '\(firstParse.firstMatch)' movement: '\(firstParse.secondMatch)' (\(firstParse.parse.name))")
                }
                if i + 1 >= collection.count {
                    //no more songs to be movements
                    //so piece name is the track name
                    piece = storePiece(from: collection[i], entitled: firstParse.firstMatch, to: album, into: context)
                    i += 1
                    continue
                }
                let secondTitle = collection[i + 1].title ?? ""
                nextParse = matchSubsequentMovement(raw: secondTitle, against: firstParse)
                if let matchedNext = nextParse {
                    if AppDelegate.showParses {
                        print("      2nd raw: '\(secondTitle)' second movt: '\(matchedNext.secondMatch)' (\(matchedNext.parse.name))")
                    }
                    //at least two movements: record piece, then first two movements
                    let pieceTitle = firstParse.firstMatch
                    piece = storePiece(from: collection[i], entitled: pieceTitle, to: album, into: context)
                    storeMovement(from: collection[i],     named: firstParse.secondMatch,  for: piece!, into: context)
                    storeMovement(from: collection[i + 1], named: matchedNext.secondMatch, for: piece!, into: context)
                    //see what other movement(s) you can find
                    i += 2
                    state = .continuePiece
                } else {
                    //next is different piece
                    //so piece name is what we found at first
                    piece = storePiece(from: collection[i], entitled: firstParse.firstMatch, to: album, into: context)
                    i += 1
                    state = .beginPiece
                }
            case .continuePiece:
                if i >= collection.count { continue }
                let subsequentTitle = collection[i].title ?? ""
                let subsequentParse = matchSubsequentMovement(raw: subsequentTitle, against: firstParse)
                 if let matchedSubsequent = subsequentParse {
                    if AppDelegate.showParses {
                        print("      Subsq raw: '\(subsequentTitle)' subsq movt: '\(matchedSubsequent.secondMatch)' (\(matchedSubsequent.parse.name))")
                    }
                    storeMovement(from: collection[i], named: matchedSubsequent.secondMatch, for: piece!, into: context)
                    i += 1
                } else {
                    state = .beginPiece //don't increment i
                }
            }
        } while i < collection.count
    }

    private func storeMovement(from item: MPMediaItem, named: String, for piece: Piece, into context: NSManagedObjectContext) {
        let mov = NSEntityDescription.insertNewObject(forEntityName: "Movement", into: context) as! Movement
        mov.title = named
        mov.trackID = AppDelegate.encodeForCoreData(id: item.persistentID)
        mov.trackURL = item.assetURL
        mov.duration = AppDelegate.durationAsString(item.playbackDuration)
        libraryMovementCount += 1
        piece.addToMovements(mov)
        if AppDelegate.showPieces { print("    '\(mov.title ?? "")'") }
        let song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: context) as! Song
        song.albumID = AppDelegate.encodeForCoreData(id: item.albumPersistentID)
        song.artist = item.artist
        song.duration = AppDelegate.durationAsString(item.playbackDuration)
        song.title = item.title
        song.trackURL = item.assetURL
        librarySongCount += 1
    }

    private func storePiece(from mediaItem: MPMediaItem, entitled title: String, to album: Album, into context: NSManagedObjectContext) -> Piece {
        if AppDelegate.showPieces && mediaItem.genre == "Classical" {
            let genreMark = (mediaItem.genre == "Classical") ? "!" : ""
            print("  \(genreMark)|\(mediaItem.composer ?? "<anon>")| \(title)")
        }
        let piece = NSEntityDescription.insertNewObject(forEntityName: "Piece", into: context) as! Piece
        piece.albumID =  AppDelegate.encodeForCoreData(id: mediaItem.albumPersistentID)
        libraryPieceCount += 1
        piece.composer = mediaItem.composer ?? ""
        piece.artist = mediaItem.artist ?? ""
        piece.artistID = AppDelegate.encodeForCoreData(id: mediaItem.artistPersistentID)
        piece.genre = mediaItem.genre ?? ""
        piece.title = title
        piece.album = album
        piece.trackID = AppDelegate.encodeForCoreData(id: mediaItem.persistentID)
        piece.trackURL = mediaItem.assetURL
        album.addToPieces(piece)
        let song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: context) as! Song
        song.albumID = AppDelegate.encodeForCoreData(id: mediaItem.albumPersistentID)
        song.artist = mediaItem.artist
        song.duration = AppDelegate.durationAsString(mediaItem.playbackDuration)
        song.title = mediaItem.title
        song.trackURL = mediaItem.assetURL
        librarySongCount += 1
        return piece
    }
    
    // MARK: - Graphics
    
    private static var _defaultImage: UIImage? = nil
    
    static var defaultImage: UIImage {
        get {
            if _defaultImage == nil {
                _defaultImage = UIImage(named: "default-album", in: nil, compatibleWith: nil)
            }
            return _defaultImage!
        }
    }
    
    private static var _brandColor: UIColor? = nil
    
    static var brandColor: UIColor {
        get {
            if _brandColor == nil {
                _brandColor = UIColor(named: "TheBlue")
            }
            return _brandColor!
        }
    }

    static func artworkFor(album: String) -> UIImage {
        let idVal = AppDelegate.decodeIDFrom(coreDataRepresentation: album)
        return AppDelegate.artworkFor(album: idVal)
    }
    
    /**
     Get artwork for an album.
     
     - Parameters:
        - album: persistentID of album
     
     - Returns:
     What's returned is (see docs) "smallest image at least as large as specified"--
     which turns out to be 600 x 600, with no discernible difference for the albums
     with iTunes LPs.
     */
    static func artworkFor(album: MPMediaEntityPersistentID) -> UIImage {
        if !UserDefaults.standard.bool(forKey: displayArtworkKey) {
            return AppDelegate.defaultImage
        }
        let query = MPMediaQuery.albums()
        let predicate = MPMediaPropertyPredicate(value: album, forProperty: MPMediaItemPropertyAlbumPersistentID)
        query.filterPredicates = Set([ predicate ])
        if let results = query.collections {
            if results.count >= 1 {
                let result = results[0].items[0]
                let propertyVal = result.value(forProperty: MPMediaItemPropertyArtwork)
                let artwork = propertyVal as? MPMediaItemArtwork
                let returnedImage = artwork?.image(at: CGSize(width: 30, height: 30))
                return returnedImage != nil ? returnedImage! : AppDelegate.defaultImage
            }
        }
        return AppDelegate.defaultImage
    }
    
    /**
     Make the animation of audio bars for currently playing audio.
    */
    private func makeAudioBarSet() {
        audioBarSet = [UIImage]()
        for imageFrame in 1...10 {
            let image = UIImage(named:"bars-\(imageFrame)")
            if let frame = image {
                audioBarSet?.append(frame)
            }
        }
        audioPaused = UIImage(named:"bars-paused")
        audioNotCurrent = UIImage(named:"bars-not-current")
    }
    
    /**
     Represesentation of a the duration of a song, suitable for display.
     */
    static func durationAsString(_ duration: TimeInterval) -> String {
        let min = Int(duration/60.0)
        let sec = Int(CGFloat(duration).truncatingRemainder(dividingBy: 60.0))
        return String(format: "%d:%02d", min, sec)
    }
    
    // MARK: - Core Data stack
    
    /**
     Media persistentIDs are UInt64, but CoreData knows nothing of that type.
     Store in CoreData as hex strings.
     Estupido.
    */
    class func encodeForCoreData(id: MPMediaEntityPersistentID) -> String {
        return String(id, radix: 16, uppercase: false)
    }
    
    /**
     Decode Media persistentID (UInt64) from hex string representation in CoreData.
    */
    class func decodeIDFrom(coreDataRepresentation: String) -> MPMediaEntityPersistentID {
        return UInt64(coreDataRepresentation, radix: 16) ?? 0
    }

    /**
     The persistent container for the application.
     This implementation
     creates and returns a container, having loaded the store for the
     application to it.
     This property is optional since there are legitimate
     error conditions that could cause the creation of the store to fail.
     
     *Errors*
     
     Typical reasons for an error here include:
     * The parent directory does not exist, cannot be created, or disallows writing.
     * The persistent store is not accessible, due to permissions or data protection when the device is locked.
     * The device is out of space.
     * The store could not be migrated to the current model version.
     Check the error message to determine what the actual problem was.

    */
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ClassicPlayer")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                NotificationCenter.default.post(Notification(name: .storeError,
                                                             object: self,
                                                             userInfo: error.userInfo))
                NSLog("store error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    /**
     Context to be used by all CoreData operations!
    */
    lazy var context: NSManagedObjectContext = {
        return persistentContainer.viewContext
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        do {
            NSLog("Saving changes")
            try context.save()
        } catch {
            let error = error as NSError
            NotificationCenter.default.post(Notification(name: .storeError,
                                                         object: self,
                                                         userInfo: error.userInfo))
            NSLog("store error \(error), \(error.userInfo)")
        }
    }

}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
