 /* 
 FrameworksToolKit.swift 

 Copyright (C) 2023, 2024 SparkleChan and SeanIsTethered 
 Copyright (C) 2024 fridakitten 

 This file is part of FridaCodeManager. 

 FridaCodeManager is free software: you can redistribute it and/or modify 
 it under the terms of the GNU General Public License as published by 
 the Free Software Foundation, either version 3 of the License, or 
 (at your option) any later version. 

 FridaCodeManager is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of 
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
 GNU General Public License for more details. 

 You should have received a copy of the GNU General Public License 
 along with FridaCodeManager. If not, see <https://www.gnu.org/licenses/>. 

  ______    _     _         _____        __ _                           ______                    _       _   _
 |  ___|  (_)   | |       /  ___|      / _| |                          |  ___|                  | |     | | (_)
 | |_ _ __ _  __| | __ _  \ `--.  ___ | |_| |___      ____ _ _ __ ___  | |_ ___  _   _ _ __   __| | __ _| |_ _  ___  _ __
 |  _| '__| |/ _` |/ _` |  `--. \/ _ \|  _| __\ \ /\ / / _` | '__/ _ \ |  _/ _ \| | | | '_ \ / _` |/ _` | __| |/ _ \| '_ \
 | | | |  | | (_| | (_| | /\__/ / (_) | | | |_ \ V  V / (_| | | |  __/ | || (_) | |_| | | | | (_| | (_| | |_| | (_) | | | |
 \_| |_|  |_|\__,_|\__,_| \____/ \___/|_|  \__| \_/\_/ \__,_|_|  \___| \_| \___/ \__,_|_| |_|\__,_|\__,_|\__|_|\___/|_| |_|
 Founded by. Sean Boleslawski, Benjamin Hornbeck and Lucienne Salim in 2023
 */ 

import Foundation

func findFrameworks(in directory: URL, SDKPath: String, ignorePaths: [String] = []) -> [String] {
    var frameworksSet = Set<String>()
    
    let fileManager = FileManager.default
    let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
    let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
    
    guard let directoryEnumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: resourceKeys, options: options) else {
        print("Failed to create directory enumerator for \(directory)")
        return []
    }
    
    let ignoreSet = Set(ignorePaths)

    for case let fileURL as URL in directoryEnumerator {
        if shouldIgnore(fileURL: fileURL, ignoreSet: ignoreSet, fileManager: fileManager) {
            continue
        }

        do {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            
            if resourceValues.isRegularFile == true {
                let fileExtension = fileURL.pathExtension.lowercased()
                if ["h", "c", "cpp", "m", "mm"].contains(fileExtension) {
                    do {
                        let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
                        let frameworkMatches = extractFrameworks(from: fileContents)
                        frameworksSet.formUnion(frameworkMatches)
                    } catch {
                        print("Error reading file \(fileURL): \(error)")
                    }
                }
            } else if resourceValues.isDirectory == true {
            } else {
                directoryEnumerator.skipDescendants()
            }
        } catch {
            print("Error reading resource values for file \(fileURL): \(error)")
        }
    }

    var frameworks: [URL] = []
    do {
        frameworks = try fileManager.contentsOfDirectory(at: URL(fileURLWithPath: "\(SDKPath)/System/Library/Frameworks"), includingPropertiesForKeys: nil) + 
                     fileManager.contentsOfDirectory(at: URL(fileURLWithPath: "\(SDKPath)/System/Library/PrivateFrameworks"), includingPropertiesForKeys: nil)
    } catch {
        print("Error while getting framework directories: \(error)")
    }
    
    let rawFW: [String] = frameworks.map { url in
        let lastPathComponent = url.lastPathComponent
        return lastPathComponent.deletingPathExtension()
    }
    
    frameworksSet = frameworksSet.filter { rawFW.contains($0) }
    return Array(frameworksSet)
}

private func shouldIgnore(fileURL: URL, ignoreSet: Set<String>, fileManager: FileManager) -> Bool {
    if ignoreSet.contains(fileURL.lastPathComponent) {
        return true
    }
    
    let parentDirectory = fileURL.deletingLastPathComponent().lastPathComponent
    if ignoreSet.contains(parentDirectory) {
        return true
    }

    return false
}

private func extractFrameworks(from contents: String) -> Set<String> {
    let pattern = "#(?:import|include)\\s+<([^/]+)/[^>]+>"
    do {
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let nsString = contents as NSString
        let matches = regex.matches(in: contents, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var frameworksSet = Set<String>()
        for match in matches {
            if match.numberOfRanges == 2 {
                let framework = nsString.substring(with: match.range(at: 1))
                frameworksSet.insert(framework)
            }
        }
        return frameworksSet
    } catch {
        print("Error creating regex: \(error)")
        return Set<String>()
    }
}

extension String {
    func deletingPathExtension() -> String {
        return (self as NSString).deletingPathExtension
    }
}
