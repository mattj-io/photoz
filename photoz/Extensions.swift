//
//  Extensions.swift
//  photoz
//
//  Created by Tyler Hall on 7/29/20.
//  Copyright © 2020 Tyler Hall. All rights reserved.
//

import Foundation

extension URL {
    var isAlbum: Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: self.path, isDirectory: &isDir)
        guard exists && isDir.boolValue else { return false }
        
        let lastComponent = self.lastPathComponent
        return lastComponent.range(of: #"^[A-Za-z]+.*$"#, options: .regularExpression) != nil
    }
    
    var isYearFolder: Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: self.path, isDirectory: &isDir)
        guard exists && isDir.boolValue else { return false }

        let lastComponent = self.lastPathComponent
        return lastComponent.range(of: #"^Photos\s+from\s+[0-9]{4}"#, options: .regularExpression) != nil
    }
}
