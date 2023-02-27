//
//  AudioFile.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 22/01/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import AVFoundation
import Foundation

/* Third-party Frameworks */
import MessageKit

public struct AudioFile: Codable, AudioItem {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Strings
    public let fileExtension: String!
    public var name: String!
    
    // Other
    public var duration: Float
    public var size: CGSize = CGSize(width: 160, height: 40)
    public var url: URL
    
    //==================================================//
    
    /* MARK: - Constructor Methods */
    
    public init(name: String,
                extension: String,
                url: URL,
                duration: Float) {
        self.name = name
        self.fileExtension = `extension`
        self.url = url
        self.duration = duration
    }
    
    public init(fromURL: URL) throws {
        guard let fileName = fromURL.absoluteString.components(separatedBy: ["/"]).last,
              fileName.components(separatedBy: ".").count == 2,
              let assetReader = try? AVAssetReader(asset: AVAsset(url: fromURL)) else {
            throw AudioFileInitializationError.failedToExtractFileMetadata
        }
        
        let components = fileName.components(separatedBy: ".")
        self.name = components[0]
        self.fileExtension = components[1]
        
        self.url = fromURL
        self.duration = Float(assetReader.asset.duration.seconds)
    }
}

public enum AudioFileInitializationError: Error {
    case failedToExtractFileMetadata
}
