//
//  SongTableViewCell.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 2/21/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import UIKit

class SongTableViewCell: UITableViewCell {
    @IBOutlet weak var artAndLabelsStack: UIStackView!
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var indicator: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var artist: UILabel!
    @IBOutlet weak var duration: UILabel!
}
