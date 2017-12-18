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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self

        let masterNavigationController = splitViewController.viewControllers[0] as! UINavigationController
        let controller = masterNavigationController.topViewController as! MasterViewController
        controller.managedObjectContext = self.persistentContainer.viewContext
        
        self.persistentContainer.performBackgroundTask { context in
            self.loadFromMedia(into: context)
        }

        return true
    }
    
    private func loadFromMedia(into context: NSManagedObjectContext) {
        //        let albumInteresting: Set = [MPMediaItemPropertyComposer, MPMediaItemPropertyAlbumArtist,
        //                                     MPMediaItemPropertyAlbumTitle,MPMediaItemPropertyAlbumTrackCount, MPMediaItemPropertyGenre ]
        //        let itemInteresting: Set = [MPMediaItemPropertyComposer, MPMediaItemPropertyArtist,
        //                                     MPMediaItemPropertyTitle, MPMediaItemPropertyGenre ]
        do {
            var discCount = 0, pieceCount = 0
            let mediaStuff = MPMediaQuery.albums()
            if mediaStuff.collections == nil {
                throw NSError(domain: "me", code: 1776, userInfo: ["a" : "something bombed"])
            }
            //I presume this is all the "songs"
            for mediaCollection in mediaStuff.collections! {
                let items = mediaCollection.items
                print("disc: \(items[0].value(forProperty: MPMediaItemPropertyComposer) ?? "<anon>"): "
                    + "\(items[0].value(forProperty: MPMediaItemPropertyAlbumTitle) ?? "<no title>")"
                    + " | \(items[0].value(forProperty: MPMediaItemPropertyAlbumArtist) ?? "<no artist>") ")
                //                items[0].enumerateValues(forProperties: albumInteresting) {
                //                    key, val, wtf in
                //                    print("key: \(key) val:\(String(describing:val)) ")
                //                }
                //                print(" val:\(String(describing:mediaCollection.count)) ")
                for /*item*/ _ in mediaCollection.items {
                    //print("  \(item.composer ?? "<anon>"): \(item.title ?? "<no title>") | \(item.artist ?? "<no artist>")")
                    //                    item.enumerateValues(forProperties: itemInteresting) {
                    //                        key, val, wtf in
                    //                        print("   key: \(key) val:\(String(describing:val)) ")
                    //                    }
                }
                let disc = NSEntityDescription.insertNewObject(forEntityName: "Disc", into: context) as! Disc
                //Someday we may purpose "artist" as a composite field containing ensemble, director, soloists
                disc.composer = items[0].value(forProperty: MPMediaItemPropertyComposer) as? String
                disc.director = ""
                disc.ensemble = items[0].value(forProperty: MPMediaItemPropertyAlbumArtist) as? String
                disc.filedUnder = "iTunes"
                disc.labelAndNumber = ""
                disc.length = ""
                disc.soloists = ""
                disc.title = items[0].value(forProperty: MPMediaItemPropertyAlbumTitle) as? String
                //let trackCount = items[0].value(forProperty: MPMediaItemPropertyAlbumTrackCount)
                //print("track ct: \(String(describing: trackCount))")
                //disc.trackCount = Int16( as? Int)
                if (items[0].value(forProperty: MPMediaItemPropertyGenre) as? String) != "Classical" {
                    loadSongs(for: disc, from: items, into: context)
                    pieceCount += items.count
                } else {
                    pieceCount += loadAndCountPieces(for: disc, from: items, into: context)
                }
                discCount += 1
            }
            print("found \(discCount) discs, \(pieceCount) pieces")
            try context.save()
            print("saved \(discCount) discs and \(pieceCount) pieces")
        } catch { // note, by default catch catches any error into a local variable called error
            let nserror = error as NSError //because JSONDecoder.decode and context.save both use NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
    
    private func loadSongs(for disc: Disc, from collection: [MPMediaItem], into context: NSManagedObjectContext) {
        for mediaItem in collection {
            _ = addPiece(from: mediaItem, entitled: mediaItem.title ?? "", to: disc, into: context)
        }
    }
    
    private func loadAndCountPieces(for disc: Disc, from collection: [MPMediaItem], into context: NSManagedObjectContext) -> Int {
        if collection.count < 1 { return 0 }
        if collection.count < 2 {
            _ = addPiece(from: collection[0], entitled: collection[0].title ?? "", to: disc, into: context)
            return 1
        }
        var piecesAdded = 0
        var movementsAdded = 0
        var i = 0
        repeat {
            if i == collection.count - 1 {
                //last item; could add as piece with no movements
                _ = addPiece(from: collection[i], entitled: collection[i].title ?? "", to: disc, into: context)
                piecesAdded += 1
                i += 1
            } else {
                let commonPrefix = sharedPrefix(collection[i].title ?? "", collection[i + 1].title ?? "")
                if commonPrefix.count < (collection[i].title ?? "").count / 2 {
                    //negligible common prefix: count as piece with no movements
                    _ = addPiece(from: collection[i], entitled: collection[i].title ?? "", to: disc, into: context)
                    piecesAdded += 1
                    i += 1
                } else {
                    //at least two movements: record piece, then first two movements
                    let piece = addPiece(from: collection[i], entitled: commonPrefix, to: disc, into: context)
                    piecesAdded += 1
                    print("  piece: \(commonPrefix)   disc: \(disc.title ?? "")")
                    let mov1 = NSEntityDescription.insertNewObject(forEntityName: "Movement", into: context) as! Movement
                    mov1.title = collection[i].title ?? "" //TODO fix this to be non-prefix
                    piece.addToMovements(mov1)
                    print("    movt: \(mov1.title ?? "")")
                    let mov2 = NSEntityDescription.insertNewObject(forEntityName: "Movement", into: context) as! Movement
                    mov2.title = collection[i + 1].title ?? "" //TODO fix this to be non-prefix
                    piece.addToMovements(mov2)
                    print("    movt: \(mov2.title ?? "")")
                    movementsAdded += 2
                    //see what other movement you can find
                    i += 2
                    while i < collection.count && sharedPrefix(commonPrefix, collection[i].title ?? "") == commonPrefix {
                        let mov = NSEntityDescription.insertNewObject(forEntityName: "Movement", into: context) as! Movement
                        mov.title = collection[i].title ?? "" //TODO fix this to be non-prefix
                        piece.addToMovements(mov)
                        print("    movt: \(mov.title ?? "")")
                        movementsAdded += 1
                        i += 1
                    }
                }
            }
        } while i < collection.count
        return piecesAdded
    }
    
    private func sharedPrefix(_ a: String, _ b: String) -> String {
        let shorter = (a.count < b.count) ? a : b
        for index in shorter.indices {
            if a[index] != b[index] {
                return String(shorter[..<index])
            }
        }
        return shorter
    }

    private func addPiece(from mediaItem: MPMediaItem, entitled title: String, to disc: Disc, into context: NSManagedObjectContext) -> Piece {
        let piece = NSEntityDescription.insertNewObject(forEntityName: "Piece", into: context) as! Piece
        piece.composer = mediaItem.composer ?? ""
        piece.director = ""
        piece.ensemble = mediaItem.artist ?? ""
        piece.soloists = ""
        piece.title = title
        piece.disc = disc
        disc.addToPieces(piece)
        return piece
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

    // MARK: - Split view

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
        guard let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController else { return false }
        if topAsDetailController.detailItem == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        }
        return false
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

