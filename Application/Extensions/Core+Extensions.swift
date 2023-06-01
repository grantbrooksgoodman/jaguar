//
//  Core+Extensions.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 06/05/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/* Third-party Frameworks */
import Translator

public extension Core {
    static func clearCaches() {
        ContactArchiver.clearArchive()
        ContactService.clearCache()
        ConversationArchiver.clearArchive()
        RecognitionService.clearCache()
        RegionDetailServer.clearCache()
        TranslationArchiver.clearArchive()
        
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.clearedCachesKey)
    }
    
    @discardableResult
    static func eraseDocumentsDirectory() -> Exception? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL,
                                                               includingPropertiesForKeys: nil,
                                                               options: .skipsHiddenFiles)
            
            for fileURL in fileURLs {
                try fileManager.removeItem(at: fileURL)
            }
        } catch let error {
            return Exception(error, metadata: [#file, #function, #line])
        }
        
        return nil
    }
    
    @discardableResult
    static func eraseTemporaryDirectory() -> Exception? {
        let fileManager = FileManager.default
        let tempFolderPath = NSTemporaryDirectory()
        
        do {
            let filePaths = try fileManager.contentsOfDirectory(atPath: tempFolderPath)
            for filePath in filePaths {
                try fileManager.removeItem(atPath: tempFolderPath + filePath)
            }
        } catch let error {
            return Exception(error, metadata: [#file, #function, #line])
        }
        
        return nil
    }
    
    static func open(_ url: URL) {
#if !EXTENSION
        UIApplication.shared.open(url)
#endif
    }
}
