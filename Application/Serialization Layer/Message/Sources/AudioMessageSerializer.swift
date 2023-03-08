//
//  AudioMessageSerializer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 22/01/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/* Third-party Frameworks */
import FirebaseStorage

// #warning("Be sure to delete unnecessary files after use.")
public struct AudioMessageSerializer {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static let shared = AudioMessageSerializer()
    
    //==================================================//
    
    /* MARK: - Upload Methods */
    
    // MARK: Public
    
    public func uploadAudioReference(for message: Message,
                                     audioComponent: (input: AudioFile, output: AudioFile),
                                     completion: @escaping(_ message: Message,
                                                           _ exception: Exception?) -> Void) {
        guard message.hasAudioComponent else {
            completion(message, Exception("Message doesn't have an audio component.",
                                          extraParams: ["MessageID": message.identifier!],
                                          metadata: [#file, #function, #line]))
            return
        }
        
        var mutableAudioComponent = audioComponent
        mutableAudioComponent.input.name = message.identifier
        
        let pathPrefix = "\(GeneralSerializer.environment.shortString)/audioMessages/"
        let subPath = "\(message.translation.languagePair.asString())/\(message.translation.serialize().key)"
        let fullPath = "\(pathPrefix)\(subPath)"
        
        let audioReference = AudioMessageReference(directoryPath: fullPath,
                                                   original: mutableAudioComponent.input,
                                                   translated: mutableAudioComponent.output)
        
        upload(reference: audioReference) { exception in
            guard exception == nil else {
                completion(message, Exception("Failed to upload audio component.",
                                              extraParams: ["MessageID": message.identifier!],
                                              metadata: [#file, #function, #line]))
                return
            }
            
            message.audioComponent = audioReference
            
            completion(message, nil)
        }
    }
    
    // MARK: Private
    
    private func upload(audioFile: AudioFile,
                        toPath: String,
                        completion: @escaping(_ exception: Exception?) -> Void) {
        let filePath = "\(toPath)/\(audioFile.name!).\(audioFile.fileExtension!)"
        
        let storageMetadata = StorageMetadata(dictionary: ["name": filePath])
        let contentType = audioFile.fileExtension == "caf" ? "audio/x-caf" : "audio/m4a"
        storageMetadata.contentType = contentType
        
        guard let data = try? Data(contentsOf: audioFile.url) else {
            completion(Exception("Couldn't get data from file path.", metadata: [#file, #function, #line]))
            return
        }
        
        Storage.storage().reference().putData(data,
                                              metadata: storageMetadata) { metadata, error in
            guard error == nil else {
                completion(Exception(error!, metadata: [#file, #function, #line]))
                return
            }
            
            completion(nil)
        }.resume()
    }
    
    private func upload(reference: AudioMessageReference,
                        completion: @escaping(_ exception: Exception?) -> Void) {
        upload(audioFile: reference.original,
               toPath: reference.directoryPath) { exception in
            guard exception == nil else {
                completion(exception!)
                return
            }
            
            upload(audioFile: reference.translated,
                   toPath: reference.directoryPath) { exception in
                guard exception == nil else {
                    completion(exception!)
                    return
                }
                
                completion(nil)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Retrieval Methods */
    
    private func getCachedAudioReference(for message: Message,
                                         completion: @escaping(_ audioReference: AudioMessageReference?,
                                                               _ exception: Exception?) -> Void) {
        guard let localFilePaths = message.localAudioFilePaths else {
            completion(nil, Exception("Message doesn't have an audio component.",
                                      extraParams: ["MessageID": message.identifier!],
                                      metadata: [#file, #function, #line]))
            return
        }
        
        guard let inputFile = try? AudioFile(fromURL: localFilePaths.inputPathURL),
              let outputFile = try? AudioFile(fromURL: localFilePaths.outputPathURL) else {
            completion(nil, Exception("Audio reference has no local copy.",
                                      extraParams: ["MessageID": message.identifier!],
                                      metadata: [#file, #function, #line]))
            return
        }
        
        let audioReference = AudioMessageReference(directoryPath: localFilePaths.directoryPathString,
                                                   original: inputFile,
                                                   translated: outputFile)
        completion(audioReference, nil)
    }
    
    private func downloadAudioReference(for message: Message,
                                        completion: @escaping(_ audioReference: AudioMessageReference?,
                                                              _ exception: Exception?) -> Void) {
        guard let localFilePaths = message.localAudioFilePaths else {
            completion(nil, Exception("Message doesn't have an audio component.",
                                      extraParams: ["MessageID": message.identifier!],
                                      metadata: [#file, #function, #line]))
            return
        }
        
        let inputFileReference = Storage.storage().reference().child("/\(localFilePaths.inputPathString)")
        let outputFileReference = Storage.storage().reference().child("/\(localFilePaths.outputPathString)")
        
        inputFileReference.write(toFile: localFilePaths.inputPathURL) { localInputPath, error in
            guard let localInputPath else {
                let exception = error == nil ? Exception(metadata: [#file, #function, #line]) : Exception(error!, metadata: [#file, #function, #line])
                guard !exception.descriptor.contains("does not exist") else {
                    Core.gcd.after(milliseconds: 500) {
                        self.downloadAudioReference(for: message) { audioReference, exception in
                            completion(audioReference, exception)
                        }
                    }
                    
                    return
                }
                
                completion(nil, exception)
                return
            }
            
            let inputFile = try? AudioFile(fromURL: localInputPath)
            guard let inputFile else {
                completion(nil, Exception("Couldn't generate input file.", metadata: [#file, #function, #line]))
                return
            }
            
            outputFileReference.write(toFile: localFilePaths.outputPathURL) { localOutputPath, error in
                guard let localOutputPath else {
                    let exception = error == nil ? Exception(metadata: [#file, #function, #line]) : Exception(error!, metadata: [#file, #function, #line])
                    guard !exception.descriptor.contains("does not exist") else {
                        Core.gcd.after(milliseconds: 500) {
                            self.downloadAudioReference(for: message) { audioReference, exception in
                                completion(audioReference, exception)
                            }
                        }
                        
                        return
                    }
                    
                    completion(nil, exception)
                    return
                }
                
                let outputFile = try? AudioFile(fromURL: localOutputPath)
                guard let outputFile else {
                    completion(nil, Exception("Couldn't generate output file.",
                                              metadata: [#file, #function, #line]))
                    return
                }
                
                let audioMessageReference = AudioMessageReference(directoryPath: localFilePaths.directoryPathString,
                                                                  original: inputFile,
                                                                  translated: outputFile)
                completion(audioMessageReference, nil)
            }
        }
    }
    
    public func retrieveAudioReference(for message: Message,
                                       completion: @escaping(_ message: Message,
                                                             _ exception: Exception?) -> Void) {
        getCachedAudioReference(for: message) { audioReference, cachedException in
            guard let audioReference else {
                self.downloadAudioReference(for: message) { audioReference, downloadException in
                    guard let audioReference else {
                        var exceptions = [Exception]()
                        if let downloadException { exceptions.append(downloadException) }
                        if let cachedException { exceptions.append(cachedException) }
                        completion(message,
                                   exceptions.compiledException ?? Exception(metadata: [#file, #function, #line]))
                        return
                    }
                    
                    message.audioComponent = audioReference
                    completion(message, nil)
                }
                
                return
            }
            
            message.audioComponent = audioReference
            completion(message, nil)
        }
    }
}
