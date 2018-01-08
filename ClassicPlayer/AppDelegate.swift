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
    private static let showParses = false
    private static let separator: Character = "|"
    private static let composerColonWorkDashMovement = try! NSRegularExpression(pattern: "[A-Z][a-z]+:\\s*([^-]+) - (.+)", options: [])
    private static let composerColonWorkNrMovement =
        try! NSRegularExpression(pattern: "[A-Z][a-z]+:\\s*([^-]+) ([1-9][0-9]*\\. .+)", options: [])
    private static let composerColonWorkRomMovement = try! NSRegularExpression(pattern:
        "[A-Z][a-z]+:\\s*([^-]+) ((?:I|II|III|IV|V|VI|VII|VIII|IX|X|XI|XII|XIII|XIV|XV|XVI|XVII|XVIII|XIX|XX)\\. .+)", options: [])
    private static let workColonDashMovement = try! NSRegularExpression(pattern: "\\s*([^-:])(?::| - )(.*)", options: [])
    private static let workNrMovement = try! NSRegularExpression(pattern: "\\s*([^-]+) ([1-9][0-9]*\\. .+)", options: [])
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
    private static let parseNames = ["colon or dash", "arabic numeral", "roman numeral"]
    private static let parseTemplate = "$1\(AppDelegate.separator)$2"

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        //You can check permission; if you don't have it, the user muct go to settings, so end
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
         return true
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
    
    private func loadFromMedia(into context: NSManagedObjectContext) {
        do {
            var albumCount = 0, pieceCount = 0
            let mediaStuff = MPMediaQuery.albums()
            if mediaStuff.collections == nil {
                throw NSError(domain: "me", code: 1776, userInfo: ["a" : "something bombed"])
            }
            for mediaCollection in mediaStuff.collections! {
                let items = mediaCollection.items
                if items[0].genre == "Classical" {
                    print("Album: \(items[0].value(forProperty: MPMediaItemPropertyComposer) ?? "<anon>"): "
                        + "\(items[0].value(forProperty: MPMediaItemPropertyAlbumTrackCount) ?? "") "
                        + "\(items[0].value(forProperty: MPMediaItemPropertyAlbumTitle) ?? "<no title>")"
                        + " | \(items[0].value(forProperty: MPMediaItemPropertyAlbumArtist) ?? "<no artist>") ")
                }
                let album = NSEntityDescription.insertNewObject(forEntityName: "Album", into: context) as! Album
                //Someday we may purpose "artist" as a composite field containing ensemble, director, soloists
                album.artist = items[0].value(forProperty: MPMediaItemPropertyAlbumArtist) as? String
                album.title = items[0].value(forProperty: MPMediaItemPropertyAlbumTitle) as? String
                let trackCount = items[0].value(forProperty: MPMediaItemPropertyAlbumTrackCount)
                //print("track ct: \(String(describing: trackCount))")
                album.trackCount = Int16(trackCount as! Int)
                let propVal = items[0].value(forProperty: MPMediaItemPropertyAlbumPersistentID)
                let numVal = propVal as? NSNumber
                album.albumID = String(describing: numVal)
                if (items[0].value(forProperty: MPMediaItemPropertyGenre) as? String) == "Classical" {
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
                piece = storePiece(from: collection[i], entitled: pieceTitle, to: album, into: context)
                piecesAdded += 1
                if i + 1 >= collection.count {
                    //no more songs to be movements
                    i += 1
                    continue
                }
                let nextParsed = checkParses(in: collection[i + 1].title ?? "")
                if nextParsed != nil && pieceTitle == nextParsed!.pieceTitle {
                    //at least two movements: record piece, then first two movements
                    storeMovement(from: collection[i],     named: parsed!.movementTitle,     for: piece!, into: context)
                    storeMovement(from: collection[i + 1], named: nextParsed!.movementTitle, for: piece!, into: context)
                    movementsAdded += 2
                    //see what other movement you can find
                    i += 2
                    state = .continuePiece
                } else {
                    //next is different piece
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


    private func storeMovement(from item: MPMediaItem, for piece: Piece, into context: NSManagedObjectContext) {
        let songTitle = item.title!
        let movementTitle: String
        if piece.title!.count < songTitle.count { //guard against erroneous parse
            let movementTitleIndex = songTitle.index(songTitle.startIndex, offsetBy: piece.title!.count)
            movementTitle = String(songTitle.suffix(from: movementTitleIndex))
        } else {
            movementTitle = ""
        }
        let mov = NSEntityDescription.insertNewObject(forEntityName: "Movement", into: context) as! Movement
        mov.title = movementTitle
        mov.trackID = String(item.persistentID, radix: 16, uppercase: false)
        piece.addToMovements(mov)
        print("    \(mov.title ?? "")")
    }

    private func storeMovement(from item: MPMediaItem, named: String, for piece: Piece, into context: NSManagedObjectContext) {
        let mov = NSEntityDescription.insertNewObject(forEntityName: "Movement", into: context) as! Movement
        mov.title = named
        mov.trackID = String(item.persistentID, radix: 16, uppercase: false)
        mov.trackURL = item.assetURL
        piece.addToMovements(mov)
        print("    \(mov.title ?? "")")
    }

    private func storePiece(from mediaItem: MPMediaItem, entitled title: String, to album: Album, into context: NSManagedObjectContext) -> Piece {
        if mediaItem.genre == "Classical" {
            let genreMark = (mediaItem.genre == "Classical") ? "!" : ""
            print("  \(genreMark)|\(mediaItem.composer ?? "<anon>")| \(title)")
        }
        if title == "Tevot" {
            print("Tevot album\(String(mediaItem.albumPersistentID)) track \(String(mediaItem.persistentID))")
        }
        let piece = NSEntityDescription.insertNewObject(forEntityName: "Piece", into: context) as! Piece
        piece.albumID = String(mediaItem.albumPersistentID, radix: 16, uppercase: false) //estupido: persistentIDs are UInt64
        piece.composer = mediaItem.composer ?? ""
        piece.director = ""
        piece.ensemble = mediaItem.artist ?? ""
        piece.genre = mediaItem.genre ?? ""
        piece.soloists = ""
        piece.title = title
        piece.album = album
        piece.trackID = String(mediaItem.persistentID, radix: 16, uppercase: false)
        piece.trackURL = mediaItem.assetURL
        album.addToPieces(piece)
        return piece
    }
    
    static func artworkFor(album: String) -> UIImage? {
        let query = MPMediaQuery.albums()
        let idVal = UInt64(album, radix: 16)
        let predicate = MPMediaPropertyPredicate(value: idVal, forProperty: MPMediaItemPropertyAlbumPersistentID)
        query.filterPredicates = Set([ predicate ])
        if query.collections == nil {
            print("album query produced nil")
            return nil
        }
        let results = query.collections!
        if results.count < 1 {
            print("album query had no hits")
            return nil
        }
        if results.count > 1 { print("album query had \(results.count) hits") }
        let result = results[0].items[0]
        let propertyVal = result.value(forProperty: MPMediaItemPropertyArtwork)
        let artwork = propertyVal as? MPMediaItemArtwork
        return artwork?.image(at: CGSize(width: 20, height: 20))
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
    
    // MARK: - Core Data stack

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

