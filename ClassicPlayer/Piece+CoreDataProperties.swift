//
//  Piece+CoreDataProperties.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 2/3/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//
//

import Foundation
import CoreData


extension Piece {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Piece> {
        return NSFetchRequest<Piece>(entityName: "Piece")
    }

    @NSManaged public var albumID: String?
    @NSManaged public var composer: String?
    @NSManaged public var director: String?
    @NSManaged public var ensemble: String?
    @NSManaged public var genre: String?
    @NSManaged public var soloists: String?
    @NSManaged public var title: String?
    @NSManaged public var trackID: String?
    @NSManaged public var trackURL: URL?
    @NSManaged public var album: Album?
    @NSManaged public var movements: NSOrderedSet?

}

// MARK: Generated accessors for movements
extension Piece {

    @objc(insertObject:inMovementsAtIndex:)
    @NSManaged public func insertIntoMovements(_ value: Movement, at idx: Int)

    @objc(removeObjectFromMovementsAtIndex:)
    @NSManaged public func removeFromMovements(at idx: Int)

    @objc(insertMovements:atIndexes:)
    @NSManaged public func insertIntoMovements(_ values: [Movement], at indexes: NSIndexSet)

    @objc(removeMovementsAtIndexes:)
    @NSManaged public func removeFromMovements(at indexes: NSIndexSet)

    @objc(replaceObjectInMovementsAtIndex:withObject:)
    @NSManaged public func replaceMovements(at idx: Int, with value: Movement)

    @objc(replaceMovementsAtIndexes:withMovements:)
    @NSManaged public func replaceMovements(at indexes: NSIndexSet, with values: [Movement])

    @objc(addMovementsObject:)
    @NSManaged public func addToMovements(_ value: Movement)

    @objc(removeMovementsObject:)
    @NSManaged public func removeFromMovements(_ value: Movement)

    @objc(addMovements:)
    @NSManaged public func addToMovements(_ values: NSOrderedSet)

    @objc(removeMovements:)
    @NSManaged public func removeFromMovements(_ values: NSOrderedSet)

}
