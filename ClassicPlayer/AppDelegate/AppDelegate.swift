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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    static let displayArtworkKey = "display_artwork_preference"
    
    private let mediaLibrary = ClassicalMediaLibrary.sharedInstance

    var window: UIWindow?
    private var audioBarSetLight: [UIImage]?
    private var audioBarSetDark: [UIImage]?
    private var audioPausedLight: UIImage?
    private var audioPausedDark: UIImage?
    var audioNotCurrent: UIImage?
    
    // MARK: - AVPlayer
    
    //let player = Player()
    let musicPlayer = MusicPlayer()

    // MARK: - App delegate
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
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
        do {
            try mediaLibrary.saveLibrary()
        } catch {
            let error = error as NSError
            NSLog("error saving on applicationWillTerminate: \(error), \(error.userInfo)")
        }
    }
    
    // MARK: - Audio
    
    private func initializeAudio() {
        mediaLibrary.initializeAudio()
        makeAudioBarSets()
    }

    // MARK: - Graphics
    
    private static var _defaultImage: UIImage? = nil
    
    static var defaultImage: UIImage = UIImage(named: "default-album", in: nil, compatibleWith: nil)!
    
    static var brandColor: UIColor = UIColor(named: "TheBlue")!

    static func artworkFor(album: String) -> UIImage {
        let idVal = ClassicalMediaLibrary.decodeIDFrom(coreDataRepresentation: album)
        return AppDelegate.artworkFor(album: idVal)
    }
    
    static func artworkFor(album: MPMediaEntityPersistentID) -> UIImage {
        if let returnedImage = ClassicalMediaLibrary.artworkFor(album: album) {
            return returnedImage
        }
        return AppDelegate.defaultImage
    }
    
    /**
     Make the animation of audio bars for currently playing audio.
    */
    private func makeAudioBarSets() {
        audioBarSetLight = [UIImage]()
        for imageFrame in 1...10 {
            let image = UIImage(named:"bars-\(imageFrame)")
            if let frame = image {
                audioBarSetLight?.append(frame)
            }
        }
        audioBarSetDark = [UIImage]()
        for imageFrame in 1...10 {
            //Yes, the image file names seem backwards
            let image = UIImage(named:"bars-light-\(imageFrame)")
            if let frame = image {
                audioBarSetDark?.append(frame)
            }
        }
        audioPausedLight = UIImage(named:"bars-paused")
        audioPausedDark = UIImage(named:"bars-light-paused")
        //no difference for dark mode!
        audioNotCurrent = UIImage(named:"bars-not-current")
    }
    
    func getAudioBarSet(for traitCollection: UITraitCollection) -> [UIImage]? {
        if #available(iOS 12, *) {
            return traitCollection.userInterfaceStyle == .dark
                ? audioBarSetDark
                : audioBarSetLight
        } else {
            return audioBarSetLight
        }
    }
    
    func getAudioPaused(for traitCollection: UITraitCollection) -> UIImage? {
        if #available(iOS 12, *) {
            return traitCollection.userInterfaceStyle == .dark
                ? audioPausedDark
                : audioPausedLight
        } else {
            return audioPausedLight
        }
    }

}
