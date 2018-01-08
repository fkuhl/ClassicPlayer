//
//  Movement+CoreDataProperties.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 1/8/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
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
    @NSManaged public var trackURL: URL?
    @NSManaged public var piece: Piece?

}
