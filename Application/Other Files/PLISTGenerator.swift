//
//  PLISTGenerator.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import Translator

public enum PLISTGenerator {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public enum Half {
        case first
        case second
    }
    
    //==================================================//
    
    /* MARK: - PLIST Generation */
    
    public static func createPLIST(from dictionary: [String: Any],
                                   fileName: String? = nil) -> String? {
        let fileManager = FileManager.default
        
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let path = documentDirectory.appending("/\(fileName ?? String(Int().random(min: 1000, max: 10000))).plist")
        
        guard !fileManager.fileExists(atPath: path) else {
            Logger.log(Exception("File already exists.",
                                 extraParams: ["FilePath": path],
                                 metadata: [#file, #function, #line]))
            return nil
        }
        
        NSData(data: Data()).write(toFile: path, atomically: true)
        NSDictionary(dictionary: dictionary).write(toFile: path, atomically: true)
        return path
    }
    
    //==================================================//
    
    /* MARK: - Text Translation */
    
    public static func translate(text: String,
                                 toHalf: Half,
                                 completion: @escaping(_ filePath: String?,
                                                       _ exception: Exception?) -> Void) {
        let languageCodeArray = Array(RuntimeStorage.languageCodeDictionary!.keys)
        
        let half = toHalf == .first ? languageCodeArray.sorted(by: { $0 < $1 })[0...languageCodeArray.count / 2] : languageCodeArray.sorted(by: { $0 < $1 })[(languageCodeArray.count / 2) + 1...languageCodeArray.count - 1]
        
        translate(text: text,
                  toLanguages: Array(half)) { filePath, exception in
            completion(filePath, exception)
        }
    }
    
    
    public static func translate(text: String,
                                 toLanguages: [String],
                                 completion: @escaping(_ filePath: String?,
                                                       _ exception: Exception?) -> Void) {
        var translations = [String: String]()
        
        let dispatchGroup = DispatchGroup()
        
        Logger.openStream(metadata: [#file, #function, #line])
        
        for (index, languageCode) in toLanguages.enumerated() {
            dispatchGroup.enter()
            
            FirebaseTranslator.shared.translate(TranslationInput(text),
                                                with: LanguagePair(from: "en",
                                                                   to: languageCode),
                                                using: .random) { returnedTranslation, exception in
                dispatchGroup.leave()
                
                guard let translation = returnedTranslation else {
                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                Logger.logToStream("Translated item \(index + 1) of \(toLanguages.count).",
                                   line: #line)
                
                translations[languageCode] = translation.output
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            Logger.closeStream(message: "All strings should be translated; complete.",
                               onLine: #line)
            
            let hash = text.compressedHash
            let hashCharacters = hash.characterArray
            let filePath = self.createPLIST(from: translations, fileName: hashCharacters[0...hashCharacters.count / 4].joined())
            
            guard let path = filePath else {
                completion(nil, Exception("Failed to generate PLIST.",
                                          metadata: [#file, #function, #line]))
                return
            }
            
            completion(path, nil)
        }
    }
}
