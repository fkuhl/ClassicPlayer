//
//  Movement+CoreDataProperties.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 12/19/17.
//  Copyright © 2017 TyndaleSoft LLC. All rights reserved.
//
//

import Foundation
import CoreData


extension Movement {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Movement> {
        return NSFetchRequest<Movement>(entityName: "Movement")
    }

    @NSManaged public var title: String?
    @NSManaged public var trackID: String?
    @NSManaged public var piece: Piece?

}
