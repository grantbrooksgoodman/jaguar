//
//  AudioMessageReference.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 22/01/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public struct AudioMessageReference: Codable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // AudioFiles
    public let original: AudioFile!
    public let translated: AudioFile!
    
    // Other
    public let directoryPath: String!
    
    //==================================================//
    
    /* MARK: - Constructor Method */
    
    public init(directoryPath: String,
                original: AudioFile,
                translated: AudioFile) {
        self.directoryPath = directoryPath
        self.original = original
        self.translated = translated
    }
}
