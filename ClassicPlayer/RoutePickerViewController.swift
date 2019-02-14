//
//  RoutePickerViewController.swift
//  ClassicalPlayer
//
//  Created by Frederick Kuhl on 2/13/19.
//  Copyright © 2019 TyndaleSoft LLC. All rights reserved.
//

import UIKit
import AVKit

class RoutePickerViewController: UIViewController, AVRoutePickerViewDelegate {
    
    @IBOutlet weak var pickerView: AVRoutePickerView!
    
    func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
        NSLog("ended presenting routes")
    }
}
