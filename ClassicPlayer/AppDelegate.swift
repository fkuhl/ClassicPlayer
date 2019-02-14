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
import AVKit

extension Notification.Name {
    static let dataAvailable       = Notification.Name("com.tyndalesoft.ClassicalPlayer.DataAvailable")
    static let libraryChanged      = Notification.Name("com.tyndalesoft.ClassicalPlayer.LibraryChanged")
    static let clearingError       = Notification.Name("com.tyndalesoft.ClassicalPlayer.ClearingError")
    static let initializingError   = Notification.Name("com.tyndalesoft.ClassicalPlayer.InitializingError")
    static let loadingError        = Notification.Name("com.tyndalesoft.ClassicalPlayer.LoadingError")
    static let savingError         = Notification.Name("com.tyndalesoft.ClassicalPlayer.SavingError")
    static let storeError          = Notification.Name("com.tyndalesoft.ClassicalPlayer.StoreError")
    static let dataMissing         = Notification.Name("com.tyndalesoft.ClassicalPlayer.DataMissing")
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private static let displayArtworkKey = "display_artwork_preference"
    /**
     Those genres which will be parsed for pieces and movements.
     For now we parse everything, so this is unused.
    */
    private static let parsedGenres = ["Classical", "Opera", "Church", "British", "Christmas"]
    private static let showParses = false
    private static let showPieces = false

    var window: UIWindow?
    var audioBarSet: [UIImage]?
    var audioPaused: UIImage?
    var audioNotCurrent: UIImage?
    var progressDelegate: ProgressDelegate?
    
    private var libraryDate: Date?
    private var libraryAlbumCount: Int32 = 0
    private var librarySongCount: Int32 = 0
    private var libraryPieceCount: Int32 = 0
    private var libraryMovementCount: Int32 = 0
    
    var mediaLibraryInfo: (date: Date?, albums: Int32, songs: Int32, pieces: Int32, movements: Int32) {
        get {
            return (date: libraryDate,
                    albums: libraryAlbumCount,
                    songs: librarySongCount,
                    pieces: libraryPieceCount,
                    movements: libraryMovementCount)
        }
    }
    
    // MARK: - AVPlayer
    
    let player = Player()
    let musicPlayer = MusicPlayer()

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
        do {
            try self.mainThreadContext.save()
        } catch {
            let error = error as NSError
            NSLog("error saving on applicationWillTerminate: \(error), \(error.userInfo)")
        }
    }

    // MARK: - Audio and library

    private func initializeAudio() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            //In addition to setting this audio mode, info.plist contains a "Required background modes" key,
            //with an "audio" ("app plays audio ... AirPlay") entry.
            try audioSession.setCategory(AVAudioSession.Category.playback,
                                         mode: AVAudioSession.Mode.default,
                                         policy: .longForm) //enable AirPlay
        } catch {
            let error = error as NSError
            NotificationCenter.default.post(Notification(name: .initializingError,
                                                         object: self,
                                                         userInfo: error.userInfo))
            NSLog("error setting category to AVAudioSessionCategoryPlayback: \(error), \(error.userInfo)")
        }
        makeAudioBarSet()
    }
    
    func checkLibraryChanged(context: NSManagedObjectContext) {
        initializeAudio()
        let libraryInfos = getMediaLibraryInfo(from: context)
        if libraryInfos.count < 1 {
            NSLog("No app library found: load media lib to app")
            loadMediaLibraryInitially(context: context)
            return
        }
        let mediaLibraryInfo = libraryInfos[0]
        if let storedLastModDate = mediaLibraryInfo.lastModifiedDate {
            if MPMediaLibrary.default().lastModifiedDate <= storedLastModDate {
                //use current data
                NSLog("media lib stored \(MPMediaLibrary.default().lastModifiedDate), app lib stored \(storedLastModDate): use current app lib")
                logCurrentNumberOfAlbums(context: context)
                updateAppDelegateLibraryInfo(from: mediaLibraryInfo)
                NotificationCenter.default.post(Notification(name: .dataAvailable))
                return
            }  else {
                NSLog("media lib stored \(MPMediaLibrary.default().lastModifiedDate), app lib data \(storedLastModDate): media lib changed, replace app lib")
                logCurrentNumberOfAlbums(context: context)
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
    
    private func updateAppDelegateLibraryInfo(from info: MediaLibraryInfo) {
        libraryDate = info.lastModifiedDate
        libraryAlbumCount = info.albumCount
        librarySongCount = info.songCount
        libraryPieceCount = info.pieceCount
        libraryMovementCount = info.movementCount
    }
    
    private func getMediaLibraryInfo(from context: NSManagedObjectContext) -> [MediaLibraryInfo] {
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
    
    private func logCurrentNumberOfAlbums(context: NSManagedObjectContext) {
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
    private func loadMediaLibraryInitially(context: NSManagedObjectContext) {
        let loadReturn = self.loadAppFromMediaLibrary(context: context)
        do {
            try context.save()
            switch (loadReturn) {
            case .normal:
                NotificationCenter.default.post(Notification(name: .dataAvailable))
            case .missingData:
                NotificationCenter.default.post(Notification(name: .dataMissing))
            }
        } catch {
            let error = error as NSError
            NotificationCenter.default.post(Notification(name: .storeError,
                                                         object: self,
                                                         userInfo: error.userInfo))
            NSLog("error saving after loadAppFromMediaLibrary: \(error), \(error.userInfo)")
        }
    }

    /**
     Clear out old app library, and replace with media library contents.
     
     Note that the load is done on a background thread!
     Because we can't update the progress bar if the CoreData stuff is hogging the main thread.
     loadAppFromMediaLibrary makes progress calls back to a delegate,
     which must handle its UI updates on main thread.
     
     - Precondition: App has authorization to access library
     */
    func replaceAppLibraryWithMedia() {
        persistentContainer.performBackgroundTask() { context in
        
            self.clearOldData(from: context)
            let loadReturn = self.loadAppFromMediaLibrary(context: context)
            do {
                try context.save()
                switch (loadReturn) {
                case .normal:
                    NotificationCenter.default.post(Notification(name: .dataAvailable))
                case .missingData:
                    NotificationCenter.default.post(Notification(name: .dataMissing))
                }
            } catch {
                let error = error as NSError
                NSLog("save error in replaceAppLibraryWithMedia: \(error), \(error.userInfo)")
                NotificationCenter.default.post(Notification(name: .storeError,
                                                             object: self,
                                                             userInfo: error.userInfo))
            }
        }
    }
    
    private func clearOldData(from context: NSManagedObjectContext) {
        do {
            try clearEntities(ofType: "Movement", from: context)
            try clearEntities(ofType: "Piece", from: context)
            try clearEntities(ofType: "Album", from: context)
            try clearEntities(ofType: "Song", from: context)
         } catch {
            let error = error as NSError
            NotificationCenter.default.post(Notification(name: .clearingError,
                                                         object: self,
                                                         userInfo: error.userInfo))
            NSLog("error clearing old data: \(error), \(error.userInfo)")
            return
        }
        do {
            try context.save()
        } catch {
            let error = error as NSError
            NotificationCenter.default.post(Notification(name: .storeError,
                                                         object: self,
                                                         userInfo: error.userInfo))
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
    
    private enum LoadReturn {
        case normal
        case missingData
    }
    
    /**
     Load the app's lib (CoreData) from media lib.
     Before this calls any parsing functions it strips any MediaItems whose assetURL is nil.
     This may affect parsing, but all parsing functions can assume no nil URLs.
     
     - Parameters:
     - context: Coredata context
     
     - Returns:
     whether any media (asset URLs) were missing.
     */
    private func loadAppFromMediaLibrary(context: NSManagedObjectContext) -> LoadReturn {
        var allMediaDataPresent = true
        NSLog("started finding composers")
        let composerResults = findComposers()
        let totalAlbumCount = Float(composerResults.0)
        composersFound = composerResults.1
        let progressIncrement = Int32(totalAlbumCount / 20) //update progress bar 20 times
        NSLog("finished finding composers")
        libraryDate = MPMediaLibrary.default().lastModifiedDate
        libraryAlbumCount = 0
        libraryPieceCount = 0
        librarySongCount = 0
        libraryMovementCount = 0
        let mediaAlbums = MPMediaQuery.albums()
        if mediaAlbums.collections == nil { return .normal }
        for mediaAlbum in mediaAlbums.collections! {
            var mediaAlbumItems = mediaAlbum.items
            //Remove items with nil assetURLs, which may mess up parsing, but oh well
            mediaAlbumItems.removeAll(where: { $0.assetURL == nil && !$0.isCloudItem })
            if scanForItemsLackingMedia(from: mediaAlbumItems) { allMediaDataPresent = false }
            self.libraryAlbumCount += 1
            if self.libraryAlbumCount % progressIncrement == 0 {
                self.progressDelegate?.setProgress(progress: Float(self.libraryAlbumCount) / totalAlbumCount)
            }
            if AppDelegate.showPieces && self.isGenreToParse(mediaAlbumItems[0].genre ) {
                print("Album: \(mediaAlbumItems[0].composer ?? "<anon>"): "
                    + "\(mediaAlbumItems[0].albumTrackCount) "
                    + "\(mediaAlbumItems[0].albumTitle ?? "<no title>")"
                    + " | \(mediaAlbumItems[0].albumArtist ?? "<no artist>")"
                    + " | \((mediaAlbumItems[0].value(forProperty: "year") as? Int) ?? -1) ")
            }
            if mediaAlbumItems.isEmpty {
                NSLog("empty album, title: '\(mediaAlbum.representativeItem?.albumTitle ?? "")'")
                continue
            }
            let appAlbum = self.makeAndFillAlbum(from: mediaAlbumItems, into: context)
            self.loadSongs(for: appAlbum, from: mediaAlbumItems, into: context)
//            if self.isGenreToParse(appAlbum.genre) {
//                self.loadParsedPieces(for: appAlbum, from: mediaAlbumItems, into: context)
//            } else {
//                self.loadSongsAsPieces(for: appAlbum, from: mediaAlbumItems, into: context)
//            }
            //For now, just parse everything irrespective of genre. One less thing to explain.
            self.loadParsedPieces(for: appAlbum, from: mediaAlbumItems, into: context)
        }
        NSLog("found \(composersFound.count) composers, \(libraryAlbumCount) albums, \(libraryPieceCount) pieces, \(libraryMovementCount) movements, \(librarySongCount) tracks")
        storeMediaLibraryInfo(into: context)
        return allMediaDataPresent ? .normal : .missingData
    }
    
    private func scanForItemsLackingMedia(from items: [MPMediaItem]) -> Bool {
        var mediaUnaccountablyMissing = false
        for item in items {
            if item.assetURL == nil {
                if item.hasProtectedAsset { NSLog("item '\(item.title ?? "")' has protected asset") }
                if item.isCloudItem { NSLog("item '\(item.title ?? "")' is cloud item") }
                if !item.hasProtectedAsset && !item.isCloudItem {
                    NSLog("item '\(item.title ?? "")' is missing media")
                    mediaUnaccountablyMissing = true
                }
            }
        }
        return mediaUnaccountablyMissing
    }
    
    private func makeAndFillAlbum(from mediaAlbumItems: [MPMediaItem], into context: NSManagedObjectContext) -> Album {
        let album = NSEntityDescription.insertNewObject(forEntityName: "Album", into: context) as! Album
        //Someday we may purpose "artist" as a composite field containing ensemble, director, soloists
        album.artist = mediaAlbumItems[0].albumArtist
        album.title = mediaAlbumItems[0].albumTitle
        album.composer = (mediaAlbumItems[0].composer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        album.genre = mediaAlbumItems[0].genre
        album.trackCount = Int32(mediaAlbumItems[0].albumTrackCount)
        album.albumID = AppDelegate.encodeForCoreData(id: mediaAlbumItems[0].albumPersistentID)
        album.year = mediaAlbumItems[0].value(forProperty: "year") as! Int32  //slightly undocumented!
        return album
    }
    
    func retrieveMediaLibraryInfo(from context: NSManagedObjectContext) {
        var mediaInfoObject: MediaLibraryInfo
        let mediaLibraryInfosInStore = getMediaLibraryInfo(from: context)
        if mediaLibraryInfosInStore.count >= 1 {
            mediaInfoObject = mediaLibraryInfosInStore[0]
            libraryDate = mediaInfoObject.lastModifiedDate
            libraryAlbumCount = mediaInfoObject.albumCount
            librarySongCount = mediaInfoObject.songCount
            libraryPieceCount = mediaInfoObject.pieceCount
            libraryMovementCount = mediaInfoObject.movementCount
        }
    }
    
    private func storeMediaLibraryInfo(into context: NSManagedObjectContext) {
        var mediaInfoObject: MediaLibraryInfo
        let mediaLibraryInfosInStore = getMediaLibraryInfo(from: context)
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
    }
    
    private func loadSongs(for album: Album, from collection: [MPMediaItem], into context: NSManagedObjectContext) {
        librarySongCount += Int32(collection.count)
        for item in collection {
            //Only record song if media data present
            let song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: context) as! Song
            song.persistentID = AppDelegate.encodeForCoreData(id: item.persistentID)
            song.albumID = AppDelegate.encodeForCoreData(id: item.albumPersistentID)
            song.artist = item.artist
            song.duration = AppDelegate.durationAsString(item.playbackDuration)
            song.title = item.title
            song.trackURL = item.assetURL
        }
    }
    
    /**
     Load the songs (tracks) of an album as individual pieces.
     Used when an album is a genre that we don't bother to parse.
     
     - Parameters:
     - for: Album CoreData object
     - from: MPMediaItems of album
     - into: Coredata context
     */
    private func loadSongsAsPieces(for album: Album, from collection: [MPMediaItem], into context: NSManagedObjectContext) {
        for mediaItem in collection {
            _ = storePiece(from: mediaItem, entitled: mediaItem.title ?? "", to: album, into: context)
        }
    }
    
    private func loadParsedPieces(for album: Album, from collection: [MPMediaItem], into context: NSManagedObjectContext) {
        var piece: Piece?
        if collection.count < 1 { return }
        let trackTitles = collection.map { return $0.title ?? "" }
        parsePieces(from: trackTitles,
                    recordPiece: { (collectionIndex: Int, pieceTitle: String, parseResult: ParseResult) in
                        piece = storePiece(from: collection[collectionIndex], entitled: pieceTitle, to: album, into: context)
                        if AppDelegate.showParses {
                            print("composer: '\(collection[collectionIndex].composer ?? "")' raw: '\(trackTitles[collectionIndex])'")
                            print("   piece: '\(parseResult.firstMatch)' movement: '\(parseResult.secondMatch)' (\(parseResult.parse.name))")
                        }
        },
                    recordMovement: { (collectionIndex: Int, movementTitle: String, parseResult: ParseResult) in
                        storeMovement(from: collection[collectionIndex], named: movementTitle, for: piece!, into: context)
                        if AppDelegate.showParses {
                            print("      movt raw: '\(trackTitles[collectionIndex])' second title: '\(movementTitle)' (\(parseResult.parse.name))")
                        }
        })
    }

    private func storeMovement(from item: MPMediaItem,
                               named: String,
                               for piece: Piece,
                               into context: NSManagedObjectContext) {
        let mov = NSEntityDescription.insertNewObject(forEntityName: "Movement", into: context) as! Movement
        mov.title = named
        mov.trackID = AppDelegate.encodeForCoreData(id: item.persistentID)
        mov.trackURL = item.assetURL
        mov.duration = AppDelegate.durationAsString(item.playbackDuration)
        libraryMovementCount += 1
        piece.addToMovements(mov)
        if AppDelegate.showPieces { print("    '\(mov.title ?? "")'") }
    }

    //assumption: check has been performed by caller that assetURL is not nil
    private func storePiece(from mediaItem: MPMediaItem,
                            entitled title: String,
                            to album: Album,
                            into context: NSManagedObjectContext) -> Piece {
        if AppDelegate.showPieces && mediaItem.genre == "Classical" {
            let genreMark = (mediaItem.genre == "Classical") ? "!" : ""
            print("  \(genreMark)|\(mediaItem.composer ?? "<anon>")| \(title)")
        }
        let piece = NSEntityDescription.insertNewObject(forEntityName: "Piece", into: context) as! Piece
        piece.albumID =  AppDelegate.encodeForCoreData(id: mediaItem.albumPersistentID)
        libraryPieceCount += 1
        piece.composer = (mediaItem.composer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        piece.artist = mediaItem.artist ?? ""
        piece.artistID = AppDelegate.encodeForCoreData(id: mediaItem.artistPersistentID)
        piece.genre = mediaItem.genre ?? ""
        piece.title = title
        piece.album = album
        piece.trackID = AppDelegate.encodeForCoreData(id: mediaItem.persistentID)
        piece.trackURL = mediaItem.assetURL
        album.addToPieces(piece)
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
        let container = NSPersistentContainer(name: "ClassicalPlayer")
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
     Context to be used by all CoreData operations on main thread
    */
    lazy var mainThreadContext: NSManagedObjectContext = {
        return persistentContainer.viewContext
    }()

    // MARK: - Core Data Saving support

//    private func save(context: NSManagedObjectContext) throws {
//        NSLog("Saving changes")
//        try context.save()
//    }

}

// MARK: - Composers


fileprivate var composersFound = Set<String>()

func composersInLibrary() -> [String] {
    return Array(composersFound)
}

/**
 Find and store all the composers that occur in songs.
 
 */
func findComposers() -> (Int, Set<String>) {
    var albumCount = 0
    var found = Set<String>()
    let mediaAlbums = MPMediaQuery.albums()
    if mediaAlbums.collections == nil { return (0, found) }
    for mediaAlbum in mediaAlbums.collections! {
        let mediaAlbumItems = mediaAlbum.items
        for item in mediaAlbumItems {
            if let composer = item.composer {
                found.insert(composer)
            }
        }
        albumCount += 1
    }
    return (albumCount, found)
}

/**
 Does the set of previously found composers contain this (possibly partial) composer name?
 
 - Parameter candidate: composer name from song title, e.g., "Brahms"
 
 - Returns: true if the candidate appears somewhere in one of the stored composers, e.g., "Brahms, Johannes".
 */
func composersContains(candidate: String) -> Bool {
    for composer in composersFound {
        if composer.range(of: candidate, options: String.CompareOptions.caseInsensitive) != nil { return true }
    }
    return false
}

// MARK: - Helper function



// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
