//
//  SpeechService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 18/01/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import AVFoundation
import Foundation
import Speech

public final class SpeechService: NSObject {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static let shared = SpeechService()
    public var isRecording: Bool {
        guard let audioRecorder else { return false }
        return audioRecorder.isRecording
    }
    
    private let synthesizer = AVSpeechSynthesizer()
    private var audioRecorder: AVAudioRecorder?
    private var recordingSession = AVAudioSession.sharedInstance()
    
    //==================================================//
    
    /* MARK: - Audio Recording */
    
    public func requestRecordingPermission(completion: @escaping(_ granted: Bool?,
                                                                 _ exception: Exception?) -> Void) {
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
            
            recordingSession.requestRecordPermission { granted in
                guard granted else {
                    completion(false, Exception("Failed to get recording permission.",
                                                metadata: [#file, #function, #line]))
                    return
                }
                
                completion(true, nil)
            }
        } catch {
            completion(nil, Exception(error,
                                      metadata: [#file, #function, #line]))
        }
    }
    
    public func startRecording(completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        let filePath = FileManager.default.documentsDirectoryURL.appendingPathComponent("input.m4a")
        
        let settings = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                      AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
             AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
        
        do {
            audioRecorder = try AVAudioRecorder(url: filePath, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            completion(nil)
        } catch {
            audioRecorder?.stop()
            completion(Exception("Failed to start recording.",
                                 metadata: [#file, #function, #line]))
        }
    }
    
    public func stopRecording(completion: @escaping(_ fileURL: URL?,
                                                    _ exception: Exception?) -> Void) {
        guard let audioRecorder else {
            completion(nil, Exception("No audio recorder to stop.",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        audioRecorder.stop()
        let url = audioRecorder.url
        
        self.audioRecorder = nil
        completion(url, nil)
    }
    
    //==================================================//
    
    /* MARK: - Speech to Text */
    
    public func requestTranscriptionPermission(completion: @escaping(_ granted: Bool,
                                                                     _ exception: Exception?) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                completion(false, Exception("Failed to get transcription permission.",
                                            metadata: [#file, #function, #line]))
                return
            }
            
            completion(true, nil)
        }
    }
    
    public func transcribeAudio(url: URL,
                                languageCode: String,
                                completion: @escaping(_ transcription: String?,
                                                      _ exception: Exception?) -> Void) {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            completion(nil, Exception("Not authorized for speech recognition.",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        let locale = Locale(identifier: languageCode)
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        if #available(iOS 16, *) {
            request.addsPunctuation = true
        }
        
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            completion(nil, Exception("Unsupported locale for speech recognition.",
                                      extraParams: ["LocaleIdentifier": locale.identifier],
                                      metadata: [#file, #function, #line]))
            return
        }
        
        recognizer.recognitionTask(with: request) { result, error in
            guard let result else {
                let exception = error == nil ? Exception(metadata: [#file, #function, #line]) : Exception(error!,
                                                                                                          metadata: [#file, #function, #line])
                completion(nil, exception)
                return
            }
            
            guard result.isFinal else {
                completion(nil, Exception("Returned transcription wasn't final.",
                                          metadata: [#file, #function, #line]))
                return
            }
            
            completion(result.bestTranscription.formattedString, nil)
        }
    }
    
    //==================================================//
    
    /* MARK: - Text to Speech */
    
    public func readToM4A(text: String,
                          language: String,
                          completion: @escaping(_ fileURL: URL?,
                                                _ exception: Exception?) -> Void) {
        getAudioFile(fromText: text, language: language) { fileURL, exception in
            guard let fileURL else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            Core.gcd.after(milliseconds: 500) {
                self.convertToM4A(from: fileURL) { fileURL, exception in
                    guard let fileURL else {
                        completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                        return
                    }
                    
                    completion(fileURL, nil)
                }
            }
        }
    }
    
    public func highestQualityVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        var applicableVoices = [AVSpeechSynthesisVoice]()
        
        for voice in voices {
            guard voice.language.lowercased().hasPrefix(languageCode.lowercased()) else { continue }
            applicableVoices.append(voice)
        }
        
        var chosenVoice: AVSpeechSynthesisVoice?
        for voice in applicableVoices {
            guard voice.quality == .enhanced,
                  chosenVoice == nil else { continue }
            chosenVoice = voice
        }
        
        return chosenVoice ?? AVSpeechSynthesisVoice(language: languageCode)
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func convertToM4A(from url: URL,
                              completion: @escaping(_ fileURL: URL?,
                                                    _ exception: Exception?) -> Void) {
        let outputURL = FileManager.default.documentsDirectoryURL.appendingPathComponent("output.m4a")
        
        let asset = AVAsset(url: url)
        let exportSession = AVAssetExportSession(asset: asset,
                                                 presetName: AVAssetExportPresetAppleM4A)
        
        guard let exportSession else {
            completion(nil, Exception("Failed to create export session.",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileManager.pathToFileInDocuments(named: "output.m4a")) {
            do {
                try fileManager.removeItem(at: outputURL)
            } catch { completion(nil, Exception(error, metadata: [#file, #function, #line])) }
        }
        
        exportSession.outputFileType = AVFileType.m4a
        exportSession.outputURL = outputURL
        exportSession.metadata = asset.metadata
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(outputURL, nil)
            default:
                let exception = exportSession.error == nil ? Exception("Failed to export file.",
                                                                       metadata: [#file, #function, #line]) : Exception(exportSession.error!, metadata: [#file, #function, #line])
                completion(nil, exception)
            }
        }
    }
    
    private func getAudioFile(fromText: String,
                              language: String,
                              completion: @escaping(_ fileURL: URL?,
                                                    _ exception: Exception?) -> Void) {
        let filePath = FileManager.default.documentsDirectoryURL.appendingPathComponent("output.caf")
        
        let utterance = AVSpeechUtterance(string: fromText)
        utterance.voice = highestQualityVoice(for: language)
        
        var output: AVAudioFile?
        var hasCompleted = false
        
        synthesizer.write(utterance) { buffer in
            guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                guard !hasCompleted else { return }
                completion(nil, Exception("Failed to generate PCM buffer.",
                                          metadata: [#file, #function, #line]))
                return
            }
            
            guard pcmBuffer.frameLength == 0,
                  let output else {
                do {
                    if output == nil {
                        output = try AVAudioFile(forWriting: filePath,
                                                 settings: pcmBuffer.format.settings,
                                                 commonFormat: .pcmFormatInt16,
                                                 interleaved: false)
                    }
                    
                    try output?.write(from: pcmBuffer)
                    
                    guard !hasCompleted else { return }
                    hasCompleted = true
                    completion(output == nil ? nil : output!.url,
                               output == nil ? Exception("Failed to generate output.",
                                                         metadata: [#file, #function, #line]) : nil)
                } catch {
                    guard !hasCompleted else { return }
                    completion(nil, Exception(error, metadata: [#file, #function, #line]))
                }
                
                return
            }
            
            guard !hasCompleted else { return }
            hasCompleted = true
            completion(output.url, nil)
        }
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: AVAudioRecorderDelegate */
extension SpeechService: AVAudioRecorderDelegate {
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder,
                                                successfully flag: Bool) {
        guard flag else {
            stopRecording { _, exception in
                guard exception == nil else {
                    Logger.log(exception!)
                    return
                }
            }
            
            return
        }
    }
}

/* MARK: FileManager */
extension FileManager {
    
    /* MARK: - Methods */
    
    func pathToFileInDocuments(named: String) -> String {
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        return documentDirectory.appending("/\(named)")
    }
    
    //--------------------------------------------------//
    
    /* MARK: - Variables */
    
    var documentsDirectoryURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
