//
//  Disc+CoreDataProperties.swift
//  CDBase
//
//  Created by Frederick Kuhl on 9/2/17.
//  Copyright © 2017 TyndaleSoft LLC. All rights reserved.
//
//

import Foundation
import CoreData


extension Disc {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Disc> {
        return NSFetchRequest<Disc>(entityName: "Disc")
    }

    @NSManaged public var composer: String?
    @NSManaged public var director: String?
    @NSManaged public var ensemble: String?
    @NSManaged public var filedUnder: String?
    @NSManaged public var labelAndNumber: String?
    @NSManaged public var length: String?
    @NSManaged public var soloists: String?
    @NSManaged public var title: String?
    @NSManaged public var trackCount: Int16
    @NSManaged public var pieces: NSSet?

}

// MARK: Generated accessors for pieces
extension Disc {

    @objc(addPiecesObject:)
    @NSManaged public func addToPieces(_ value: Piece)

    @objc(removePiecesObject:)
    @NSManaged public func removeFromPieces(_ value: Piece)

    @objc(addPieces:)
    @NSManaged public func addToPieces(_ values: NSSet)

    @objc(removePieces:)
    @NSManaged public func removeFromPieces(_ values: NSSet)

}
