//
//  Album+CoreDataProperties.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 12/22/17.
//  Copyright © 2017 TyndaleSoft LLC. All rights reserved.
//
//

import Foundation
import CoreData


extension Album {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Album> {
        return NSFetchRequest<Album>(entityName: "Album")
    }

    @NSManaged public var albumID: String?
    @NSManaged public var title: String?
    @NSManaged public var trackCount: Int16
    @NSManaged public var artist: String?
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
