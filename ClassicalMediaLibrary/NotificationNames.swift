//
//  NotificationNames.swift
//  ClassicalPlayer
//
//  Created by Frederick Kuhl on 6/25/19.
//  Copyright © 2019 TyndaleSoft LLC. All rights reserved.
//

import Foundation


extension Notification.Name {
    static let dataAvailable       = Notification.Name("com.tyndalesoft.ClassicalPlayer.DataAvailable")
    static let libraryChanged      = Notification.Name("com.tyndalesoft.ClassicalPlayer.LibraryChanged")
    static let clearingError       = Notification.Name("com.tyndalesoft.ClassicalPlayer.ClearingError")
    static let initializingError   = Notification.Name("com.tyndalesoft.ClassicalPlayer.InitializingError")
    static let loadingError        = Notification.Name("com.tyndalesoft.ClassicalPlayer.LoadingError")
    static let savingError         = Notification.Name("com.tyndalesoft.ClassicalPlayer.SavingError")
    static let storeError          = Notification.Name("com.tyndalesoft.ClassicalPlayer.StoreError")
    static let dataMissing         = Notification.Name("com.tyndalesoft.ClassicalPlayer.DataMissing")
}
