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
    static let dataAvailable = Notification.Name("DataAvailable")
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private static let displayArtworkKey = "display_artwork_preference"
    private static let parsedGenres = ["Classical", "Opera"]
    private static let showParses = false
    private static let separator: Character = "|"
    private static let composerColonWorkDashMovement = try! NSRegularExpression(pattern: "[A-Z][a-z]+:\\s*([^-]+) -\\s+(.+)", options: [])
    private static let composerColonWorkNrMovement =
        try! NSRegularExpression(pattern: "[A-Z][a-z]+:\\s*([^-]+) +([1-9][0-9]*\\. .+)", options: [])
    private static let composerColonWorkRomMovement = try! NSRegularExpression(pattern:
        "[A-Z][a-z]+:\\s*([^-]+)\\s+((?:I|II|III|IV|V|VI|VII|VIII|IX|X|XI|XII|XIII|XIV|XV|XVI|XVII|XVIII|XIX|XX)\\. .+)", options: [])
    private static let workColonDashMovement = try! NSRegularExpression(pattern: "\\s*([^-:])(?:: +| -\\s+)(.*)", options: [])
    private static let workNrMovement = try! NSRegularExpression(pattern: "\\s*([^-]+)\\s+([1-9][0-9]*\\. .+)", options: [])
     private static let workRomMovement = try! NSRegularExpression(pattern:
        "\\s*([^-]+) ((?:I|II|III|IV|V|VI|VII|VIII|IX|X|XI|XII|XIII|XIV|XV|XVI|XVII|XVIII|XIX|XX)\\. .+)", options: [])
    private static let parseExpressions = [
        composerColonWorkDashMovement,
        composerColonWorkNrMovement,
        composerColonWorkRomMovement,
        workColonDashMovement,
        workNrMovement,
        workRomMovement
    ]
    private static let parseNames = ["composerColonWorkDashMovement", "composerColonWorkNrMovement", "composerColonWorkRomMovement",
                                     "workColonDashMovement", "workNrMovement", "workRomMovement"]
    private static let parseTemplate = "$1\(AppDelegate.separator)$2"

    var window: UIWindow?
    var audioBarSet: [UIImage]?
    var audioPaused: UIImage?
    var audioNotCurrent: UIImage?

    // MARK: - App delegate

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        initializeAudio()
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
            try audioSession.setCategory(AVAudioSessionCategoryPlayback)
        } catch {
            print("Setting category to AVAudioSessionCategoryPlayback failed.")
        }
        //You can check permission; if you don't have it, the user must go to settings, so end
        switch MPMediaLibrary.authorizationStatus() {
        case .authorized:
            self.persistentContainer.performBackgroundTask { context in
                self.clearAndLoad(into: context)
            }
        default:
            MPMediaLibrary.requestAuthorization { status in
                switch status {
                case .authorized:
                    //TODO This occurs if app wasn't installed: app asks for permission. When it gets it, the media are read, but UI isn't updated, because ComposersVC has already appeared.
                    self.persistentContainer.performBackgroundTask { context in
                        self.clearAndLoad(into: context)
                    }
                default:
                    //TODO App is installed, but user (apparently) revoked permission. Need to ask again?›
                    print("no permission")
                    exit(1)
                }
            }
        }
        makeAudioBarSet()
    }
    
    private func clearAndLoad(into context: NSManagedObjectContext) {
        do {
            try clearEntities(ofType: "Movement", from: context)
            try clearEntities(ofType: "Piece", from: context)
            try clearEntities(ofType: "Album", from: context)
            try context.save()
            self.loadFromMedia(into: context)
            try context.save()
            NotificationCenter.default.post(Notification(name: .dataAvailable))
        } catch {
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
    
    private func clearEntities(ofType type: String, from context: NSManagedObjectContext) throws {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest<NSFetchRequestResult>()
        request.entity = NSEntityDescription.entity(forEntityName: type, in:context)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        request.predicate = NSPredicate(format: "title MATCHES %@", ".*")
        deleteRequest.resultType = .resultTypeCount
        let deleteResult = try context.execute(deleteRequest) as? NSBatchDeleteResult
        print("deleted \(deleteResult?.result ?? "<nil>") \(type)")
    }
    
    private func isGenreToParse(_ optionalGenre: String?) -> Bool {
        guard let genre = optionalGenre else {
            return false
        }
        return AppDelegate.parsedGenres.contains(genre)
    }
    
    private func loadFromMedia(into context: NSManagedObjectContext) {
        do {
            var albumCount = 0, pieceCount = 0
            let mediaStuff = MPMediaQuery.albums()
            if mediaStuff.collections == nil {
                throw NSError(domain: "me", code: 1776, userInfo: ["a" : "something bombed"])
            }
            for mediaCollection in mediaStuff.collections! {
                let items = mediaCollection.items
                if isGenreToParse(items[0].genre) {
                    print("Album: \(items[0].value(forProperty: MPMediaItemPropertyComposer) ?? "<anon>"): "
                        + "\(items[0].value(forProperty: MPMediaItemPropertyAlbumTrackCount) ?? "") "
                        + "\(items[0].value(forProperty: MPMediaItemPropertyAlbumTitle) ?? "<no title>")"
                        + " | \(items[0].value(forProperty: MPMediaItemPropertyAlbumArtist) ?? "<no artist>") ")
                }
                let album = NSEntityDescription.insertNewObject(forEntityName: "Album", into: context) as! Album
                //Someday we may purpose "artist" as a composite field containing ensemble, director, soloists
                album.artist = items[0].albumArtist
                album.title = items[0].albumTitle
                album.composer = items[0].composer
                album.genre = items[0].genre
                album.trackCount = Int32(items[0].albumTrackCount)
                album.albumID = AppDelegate.encodeForCoreData(id: items[0].albumPersistentID)
                if let timeInterval = items[0].releaseDate?.timeIntervalSince1970 {
                    album.releaseDate = NSDate(timeIntervalSince1970: timeInterval)
                } else {
                    album.releaseDate = nil
                }
                if isGenreToParse(album.genre) {
                    pieceCount += loadAndCountPieces(for: album, from: items, into: context)
                } else {
                    loadSongs(for: album, from: items, into: context)
                    pieceCount += items.count
                }
                albumCount += 1
            }
            print("found \(albumCount) discs, \(pieceCount) pieces")
            try context.save()
            print("saved \(albumCount) discs and \(pieceCount) pieces")
        } catch { // note, by default catch catches any error into a local variable called error
            let nserror = error as NSError //because JSONDecoder.decode and context.save both use NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
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
    
    private func loadAndCountPieces(for album: Album, from collection: [MPMediaItem], into context: NSManagedObjectContext) -> Int {
        if collection.count < 1 { return 0 }
        if collection.count < 2 {
            _ = storePiece(from: collection[0], entitled: collection[0].title ?? "", to: album, into: context)
            return 1
        }
        var piecesAdded = 0
        var movementsAdded = 0
        var state = LoadingState.beginPiece
        var i = 0
        var piece: Piece?
        repeat {
            let unwrappedTitle = collection[i].title ?? ""
            let parsed = checkParses(in: unwrappedTitle)
            switch state {
            case .beginPiece:
                let pieceTitle = parsed?.pieceTitle ?? unwrappedTitle
                if i + 1 >= collection.count {
                    //no more songs to be movements
                    //so piece name is the track name
                    piece = storePiece(from: collection[i], entitled: unwrappedTitle, to: album, into: context)
                    piecesAdded += 1
                    i += 1
                    continue
                }
                let nextParsed = checkParses(in: collection[i + 1].title ?? "")
                if nextParsed != nil && pieceTitle == nextParsed!.pieceTitle {
                    //at least two movements: record piece, then first two movements
                    let pieceTitle = parsed?.pieceTitle ?? unwrappedTitle
                    piece = storePiece(from: collection[i], entitled: pieceTitle, to: album, into: context)
                    piecesAdded += 1
                    storeMovement(from: collection[i],     named: parsed!.movementTitle,     for: piece!, into: context)
                    storeMovement(from: collection[i + 1], named: nextParsed!.movementTitle, for: piece!, into: context)
                    movementsAdded += 2
                    //see what other movement you can find
                    i += 2
                    state = .continuePiece
                } else {
                    //next is different piece
                    //so piece name is the track name
                    piece = storePiece(from: collection[i], entitled: unwrappedTitle, to: album, into: context)
                    piecesAdded += 1
                    i += 1
                    state = .beginPiece
                }
            case .continuePiece:
                if i >= collection.count { continue }
                if parsed != nil && piece!.title == parsed!.pieceTitle {
                    storeMovement(from: collection[i], named: parsed!.movementTitle, for: piece!, into: context)
                    movementsAdded += 1
                    i += 1
                } else {
                    state = .beginPiece //don't increment i
                }
            }
        } while i < collection.count
        return piecesAdded
    }
    
    private func checkParses(in raw: String)-> (pieceTitle: String, movementTitle: String)? {
        for i in 0..<AppDelegate.parseExpressions.count {
            let transformed = AppDelegate.parseExpressions[i].stringByReplacingMatches(
                in: raw,
                options: [],
                range: NSRange(raw.startIndex..., in: raw),
                withTemplate: AppDelegate.parseTemplate)
            let components = transformed.split(separator: AppDelegate.separator, maxSplits: 6, omittingEmptySubsequences: false)
            if components.count == 2 {
                if AppDelegate.showParses { print("raw:\(raw) passed \(AppDelegate.parseNames[i])") }
                return (pieceTitle: String(components[0]), movementTitle: String(components[1]))
            } else {
                if AppDelegate.showParses { print("raw:\(raw) failed \(AppDelegate.parseNames[i])") }
            }
        }
        return nil
    }

    private func storeMovement(from item: MPMediaItem, named: String, for piece: Piece, into context: NSManagedObjectContext) {
        let mov = NSEntityDescription.insertNewObject(forEntityName: "Movement", into: context) as! Movement
        mov.title = named
        mov.trackID = AppDelegate.encodeForCoreData(id: item.persistentID)
        mov.trackURL = item.assetURL
        mov.duration = AppDelegate.durationAsString(item.playbackDuration)
        piece.addToMovements(mov)
        print("    '\(mov.title ?? "")'")
    }

    private func storePiece(from mediaItem: MPMediaItem, entitled title: String, to album: Album, into context: NSManagedObjectContext) -> Piece {
        if mediaItem.genre == "Classical" {
            let genreMark = (mediaItem.genre == "Classical") ? "!" : ""
            print("  \(genreMark)|\(mediaItem.composer ?? "<anon>")| \(title)")
        }
        let piece = NSEntityDescription.insertNewObject(forEntityName: "Piece", into: context) as! Piece
        piece.albumID =  AppDelegate.encodeForCoreData(id: mediaItem.albumPersistentID)
        piece.composer = mediaItem.composer ?? ""
        piece.director = ""
        piece.ensemble = mediaItem.artist ?? ""
        piece.genre = mediaItem.genre ?? ""
        piece.soloists = ""
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
                //What's returned is (see docs) "smallest image at least as large as specified"--
                //which turns out to be 600 x 600, with no discernible difference for the albums
                //with iTunes LPs.
                return returnedImage != nil ? returnedImage! : AppDelegate.defaultImage
            }
        }
        return AppDelegate.defaultImage
    }
    
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
    
    static func durationAsString(_ duration: TimeInterval) -> String {
        let min = Int(duration/60.0)
        let sec = Int(CGFloat(duration).truncatingRemainder(dividingBy: 60.0))
        return String(format: "%d:%02d", min, sec)
    }
    
    static func yearFrom(releaseDate: NSDate?) -> String {
        let yearText: String
        if let timeInterval = releaseDate?.timeIntervalSince1970 {
            let releaseDate = Date(timeIntervalSince1970: timeInterval)
            let calendar = Calendar.current
            yearText = "\(calendar.component(.year, from: releaseDate))"
        } else {
            yearText = "[n.d.]"
        }
        return yearText
    }
    
    // MARK: - Core Data stack
    
    //estupido: persistentIDs are UInt64, but CoreData knows nothing of them. Store as hex strings
    class func encodeForCoreData(id: MPMediaEntityPersistentID) -> String {
        return String(id, radix: 16, uppercase: false)
    }
    
    class func decodeIDFrom(coreDataRepresentation: String) -> MPMediaEntityPersistentID {
        return UInt64(coreDataRepresentation, radix: 16) ?? 0
    }

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "ClassicPlayer")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    lazy var context: NSManagedObjectContext = {
        return persistentContainer.viewContext
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}

