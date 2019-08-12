//
//  ClassicalMediaLibrary.swift
//  ClassicalPlayer
//
//  Created by Frederick Kuhl on 8/12/19.
//  Copyright © 2019 TyndaleSoft LLC. All rights reserved.
//

import Foundation
import CoreData
import MediaPlayer
import AVKit

public class ClassicalMediaLibrary {
    
    // MARK: - Singleton
    
    public static let sharedInstance = ClassicalMediaLibrary()
    private init() {}
    
    /**
     Those genres which will be parsed for pieces and movements.
     For now we parse everything, so this is unused.
    */
    private static let parsedGenres = ["Classical", "Opera", "Church", "British", "Christmas"]
    private static let showParses = false
    private static let showPieces = false
    
    public var progressDelegate: ProgressDelegate?

    
    private var libraryDate: Date?
    private var libraryAlbumCount: Int32 = 0
    private var librarySongCount: Int32 = 0
    private var libraryPieceCount: Int32 = 0
    private var libraryMovementCount: Int32 = 0
    
    public var mediaLibraryInfo: (date: Date?, albums: Int32, songs: Int32, pieces: Int32, movements: Int32) {
        get {
            return (date: libraryDate,
                    albums: libraryAlbumCount,
                    songs: librarySongCount,
                    pieces: libraryPieceCount,
                    movements: libraryMovementCount)
        }
    }
    
    // MARK: - Audio

    public func initializeAudio() {
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
    }
    
    // MARK: - Media library info

    func checkLibraryChanged(context: NSManagedObjectContext) {
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

    private func isGenreToParse(_ optionalGenre: String?) -> Bool {
        guard let genre = optionalGenre else {
            return false
        }
        return ClassicalMediaLibrary.parsedGenres.contains(genre)
    }
    
    // MARK: - Load app from Media library

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
        findComposers()
        NSLog("finished finding \(composersCount()) composers")
        libraryDate = MPMediaLibrary.default().lastModifiedDate
        libraryAlbumCount = 0
        libraryPieceCount = 0
        librarySongCount = 0
        libraryMovementCount = 0
        loadAllSongs(into: context)
        let progressIncrement = Int32(max(1, getAlbumCount() / 20)) //update progress bar 20 times
        let mediaAlbums = MPMediaQuery.albums()
        if let collections = mediaAlbums.collections {
            for mediaAlbum in collections {
                var mediaAlbumItems = mediaAlbum.items
                mediaAlbumItems.removeAll(where: { !$0.isPlayable() })
                if someItemsMissingMedia(from: mediaAlbumItems) { allMediaDataPresent = false }
                self.libraryAlbumCount += 1
                if self.libraryAlbumCount % progressIncrement == 0 {
                    self.progressDelegate?.setProgress(progress: Float(self.libraryAlbumCount) / Float(getAlbumCount()))
                }
                if ClassicalMediaLibrary.showPieces && self.isGenreToParse(mediaAlbumItems[0].genre ) {
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
                //            if self.isGenreToParse(appAlbum.genre) {
                //                self.loadParsedPieces(for: appAlbum, from: mediaAlbumItems, into: context)
                //            } else {
                //                self.loadSongsAsPieces(for: appAlbum, from: mediaAlbumItems, into: context)
                //            }
                //For now, just parse everything irrespective of genre. One less thing to explain.
                self.loadParsedPieces(for: appAlbum, from: mediaAlbumItems, into: context)
            }
        }
        NSLog("found \(composersCount()) composers, \(libraryAlbumCount) albums, \(libraryPieceCount) pieces, \(libraryMovementCount) movements, \(librarySongCount) tracks")
        storeMediaLibraryInfo(into: context)
        return allMediaDataPresent ? .normal : .missingData
    }
    
    private func someItemsMissingMedia(from items: [MPMediaItem]) -> Bool {
        return items.reduce(false, { wereMissing, item in
            wereMissing || (item.playabilityCategory() == .missingMedia)
        })
    }
    
    private func makeAndFillAlbum(from mediaAlbumItems: [MPMediaItem], into context: NSManagedObjectContext) -> Album {
        let album = NSEntityDescription.insertNewObject(forEntityName: "Album", into: context) as! Album
        //Someday we may purpose "artist" as a composite field containing ensemble, director, soloists
        album.artist = mediaAlbumItems[0].albumArtist
        album.title = mediaAlbumItems[0].albumTitle
        album.composer = (mediaAlbumItems[0].composer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        album.genre = mediaAlbumItems[0].genre
        album.trackCount = Int32(mediaAlbumItems[0].albumTrackCount)
        album.albumID = ClassicalMediaLibrary.encodeForCoreData(id: mediaAlbumItems[0].albumPersistentID)
        album.year = mediaAlbumItems[0].value(forProperty: "year") as! Int32  //slightly undocumented!
        return album
    }
    
    /**
     Load all songs from the library.
     This collects all songs, whether they are part of an album or not.
     As the code has developed it's not clear that we still need a CoreData Song object.
     */
    private func loadAllSongs(into context: NSManagedObjectContext) {
        if let items = MPMediaQuery.songs().items {
            librarySongCount = Int32(0)
            for item in items {
                if !item.isPlayable() { continue }
                librarySongCount += 1
                let song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: context) as! Song
                song.persistentID = ClassicalMediaLibrary.encodeForCoreData(id: item.persistentID)
                song.albumID = ClassicalMediaLibrary.encodeForCoreData(id: item.albumPersistentID)
                song.artist = item.artist
                song.duration = ClassicalMediaLibrary.durationAsString(item.playbackDuration)
                song.title = item.title
                song.trackURL = item.assetURL
            }
        }
    }

    /**
     Load the songs (tracks) of an album as individual pieces.
     Used when an album is a genre that we don't bother to parse.
     (At present this is irrelevant because we parse everything.)
     
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
                        if ClassicalMediaLibrary.showParses {
                            print("composer: '\(collection[collectionIndex].composer ?? "")' raw: '\(trackTitles[collectionIndex])'")
                            print("   piece: '\(parseResult.firstMatch)' movement: '\(parseResult.secondMatch)' (\(parseResult.parse.name))")
                        }
        },
                    recordMovement: { (collectionIndex: Int, movementTitle: String, parseResult: ParseResult) in
                        storeMovement(from: collection[collectionIndex], named: movementTitle, for: piece!, into: context)
                        if ClassicalMediaLibrary.showParses {
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
        mov.trackID = ClassicalMediaLibrary.encodeForCoreData(id: item.persistentID)
        mov.trackURL = item.assetURL
        mov.duration = ClassicalMediaLibrary.durationAsString(item.playbackDuration)
        libraryMovementCount += 1
        piece.addToMovements(mov)
        if ClassicalMediaLibrary.showPieces { print("    '\(mov.title ?? "")'") }
    }

    //assumption: check has been performed by caller that assetURL is not nil
    private func storePiece(from mediaItem: MPMediaItem,
                            entitled title: String,
                            to album: Album,
                            into context: NSManagedObjectContext) -> Piece {
        if ClassicalMediaLibrary.showPieces && mediaItem.genre == "Classical" {
            let genreMark = (mediaItem.genre == "Classical") ? "!" : ""
            print("  \(genreMark)|\(mediaItem.composer ?? "<anon>")| \(title)")
        }
        let piece = NSEntityDescription.insertNewObject(forEntityName: "Piece", into: context) as! Piece
        piece.albumID =  ClassicalMediaLibrary.encodeForCoreData(id: mediaItem.albumPersistentID)
        libraryPieceCount += 1
        piece.composer = (mediaItem.composer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        piece.artist = mediaItem.artist ?? ""
        piece.artistID = ClassicalMediaLibrary.encodeForCoreData(id: mediaItem.artistPersistentID)
        piece.genre = mediaItem.genre ?? ""
        piece.title = title
        piece.album = album
        piece.trackID = ClassicalMediaLibrary.encodeForCoreData(id: mediaItem.persistentID)
        piece.trackURL = mediaItem.assetURL
        album.addToPieces(piece)
        return piece
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
    public static func artworkFor(album: MPMediaEntityPersistentID) -> UIImage? {
        //In build 21, artwork is always enabled!
        //        if !UserDefaults.standard.bool(forKey: displayArtworkKey) {
        //            return AppDelegate.defaultImage
        //        }
        let query = MPMediaQuery.albums()
        let predicate = MPMediaPropertyPredicate(value: album, forProperty: MPMediaItemPropertyAlbumPersistentID)
        query.filterPredicates = Set([ predicate ])
        if let results = query.collections {
            if results.count >= 1 {
                let result = results[0].items[0]
                let propertyVal = result.value(forProperty: MPMediaItemPropertyArtwork)
                let artwork = propertyVal as? MPMediaItemArtwork
                let returnedImage = artwork?.image(at: CGSize(width: 30, height: 30))
                return returnedImage
            }
        }
        return nil
    }
    
    /**
     Represesentation of a the duration of a song, suitable for display.
     */
    public static func durationAsString(_ duration: TimeInterval) -> String {
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
    public class func encodeForCoreData(id: MPMediaEntityPersistentID) -> String {
        return String(id, radix: 16, uppercase: false)
    }
    
    /**
     Decode Media persistentID (UInt64) from hex string representation in CoreData.
     
     - Parameters:
        - coreDataRepresentation: persistentID in CoreData form, i.e., as hex string
     
     - Returns:
     UInt64, or 0 if decoding failure
    */
    public class func decodeIDFrom(coreDataRepresentation: String) -> MPMediaEntityPersistentID {
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
    public lazy var persistentContainer: NSPersistentContainer = {
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
    public lazy var mainThreadContext: NSManagedObjectContext = {
        return persistentContainer.viewContext
    }()
    
    public func saveLibrary() throws {
        try self.mainThreadContext.save()
    }

}
