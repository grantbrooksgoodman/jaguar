//
//  LogFile.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public struct LogFile {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Strings
    public let directoryName: String!
    public let fileName: String!
    
    // Other
    public let data: Data!
    
    //==================================================//
    
    /* MARK: - Constructor */
    
    public init(fileName: String,
                directoryName: String,
                data: Data) {
        self.fileName = fileName
        self.directoryName = directoryName
        self.data = data
    }
}
