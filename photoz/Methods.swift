//
//  Methods.swift
//  photoz
//
//  Created by Tyler Hall on 8/22/20.
//  Copyright © 2020 Tyler Hall. All rights reserved.
//

import Foundation
import Checksum

func generateAllHashes() {
    // I prefer to crash if this fails for some reason
    let directories = try! FileManager.default.contentsOfDirectory(at: libraryURL, includingPropertiesForKeys: nil, options: [FileManager.DirectoryEnumerationOptions.skipsHiddenFiles])
    for dirURL in directories {
        print("# Scanning Directory: \(dirURL.path)")

        var dirType: DirType
        if dirURL.isYearFolder {
            dirType = .Year
        } else if dirURL.isAlbum {
            dirType = .Album
        } else {
            continue // I don't want to touch directories that aren't in a format I'm expecting.
        }

        guard let files = try? FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil, options: [FileManager.DirectoryEnumerationOptions.skipsHiddenFiles]) else { continue }

        for fileURL in files {
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir)
            if !exists || isDir.boolValue {
                continue
            }

            if(fileURL.pathExtension.lowercased() == "json") {
                try? FileManager.default.removeItem(at: fileURL)
                continue
            }

            let op = BlockOperation {
                print("## Calculating Hash \(operationQueue.operationCount): \(fileURL.path)")
                if let md5 = fileURL.checksum(algorithm: .md5) {
                    let lib = libraryURL.path
                    let file = fileURL.path
                    let relative = file.replacingOccurrences(of: lib, with: "")

                    queue?.inDatabase({ (db) in
                        do {
                            try db.executeUpdate("INSERT INTO photo_hashes (path, hash, dir_type) VALUES (?, ?, ?)", values: [relative, md5, dirType.rawValue])
                        } catch {
                            fatalError("Could not insert hash for \(fileURL.path)")
                        }
                    })
                }
            }
            operationQueue.addOperation(op)
        }
    }

    operationQueue.waitUntilAllOperationsAreFinished()
}

func organizeLibrary() {
    queue?.inDatabase({ (db) in
        guard let results = try? db.executeQuery("SELECT * FROM photo_hashes WHERE dir_type = ?", values: [DirType.Year.rawValue]) else { fatalError() }
        
        while results.next() {
            guard let path = results.string(forColumn: "path") else { fatalError() }
            guard let hash = results.string(forColumn: "hash") else { fatalError() }

            guard let countResults = try? db.executeQuery("SELECT COUNT(*) FROM photo_hashes WHERE hash = ? AND dir_type != ?", values: [hash, DirType.Year.rawValue]) else { fatalError() }
            if countResults.next() {
                let count = countResults.int(forColumnIndex: 0)
                if count == 0 {
					print("### No Dupes \(path)")
					continue
                } else {
                    print("### Duplicate \(path)")
					let originalFileURL = libraryURL.appendingPathComponent(path)
                    print("###### DELETING")
                    try? FileManager.default.removeItem(at: originalFileURL)
                }
            }
            countResults.close()
        }
    })
}


func mergeIntoLibrary() {
    let directories = try! FileManager.default.contentsOfDirectory(at: importURL, includingPropertiesForKeys: nil, options: [FileManager.DirectoryEnumerationOptions.skipsHiddenFiles])
    for dirURL in directories {
        print("# Scanning Import Directory: \(dirURL.path)")
        
        let dirName = dirURL.lastPathComponent
        let dirLibURL = libraryURL.appendingPathComponent(dirName)
        try? FileManager.default.createDirectory(at: dirLibURL, withIntermediateDirectories: true, attributes: nil)

        guard let files = try? FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil, options: [FileManager.DirectoryEnumerationOptions.skipsHiddenFiles]) else { continue }

        for fileURL in files {
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir)
            if !exists || isDir.boolValue {
                continue
            }

            if(fileURL.pathExtension.lowercased() == "json") {
                try? FileManager.default.removeItem(at: fileURL)
                continue
            }
            
            let filename = fileURL.lastPathComponent
            var destURL = dirLibURL.appendingPathComponent(filename)
            var numericSuffix = 0
            while(FileManager.default.fileExists(atPath: destURL.path)) {
                numericSuffix += 1

                if let dotIndex = filename.lastIndex(of: ".") {
                    var potentialFilename = filename
                    potentialFilename.insert(contentsOf: " (\(numericSuffix))", at: dotIndex)
                    destURL = dirLibURL.appendingPathComponent(potentialFilename)
                } else {
                    let potentialFilename = filename + " (\(numericSuffix))"
                    destURL = dirLibURL.appendingPathComponent(potentialFilename)
                }
            }

            try! FileManager.default.moveItem(at: fileURL, to: destURL) // I prefer to crash if this fails for some reason
        }
    }

    operationQueue.waitUntilAllOperationsAreFinished()
}
