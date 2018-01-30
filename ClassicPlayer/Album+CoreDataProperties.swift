//
//  Album+CoreDataProperties.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/30/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//
//

import Foundation
import CoreData


extension Album {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Album> {
        return NSFetchRequest<Album>(entityName: "Album")
    }

    @NSManaged public var albumID: String?
    @NSManaged public var artist: String?
    @NSManaged public var composer: String?
    @NSManaged public var genre: String?
    @NSManaged public var title: String?
    @NSManaged public var trackCount: Int32
    @NSManaged public var releaseDate: NSDate?
    @NSManaged public var pieces: NSSet?

}

// MARK: Generated accessors for pieces
extension Album {

    @objc(addPiecesObject:)
    @NSManaged public func addToPieces(_ value: Piece)

    @objc(removePiecesObject:)
    @NSManaged public func removeFromPieces(_ value: Piece)

    @objc(addPieces:)
    @NSManaged public func addToPieces(_ values: NSSet)

    @objc(removePieces:)
    @NSManaged public func removeFromPieces(_ values: NSSet)

}
