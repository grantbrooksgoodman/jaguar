//
//  AudioMessageService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/01/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import AVFoundation
import Foundation
import UIKit

/* Third-party Frameworks */
import AlertKit
import InputBarAccessoryView
import Translator

public protocol AudioMessageDelegate {
    var messageInputBar: InputBarAccessoryView { get }
    var view: UIView! { get set }
}

public class AudioMessageService: NSObject, UIGestureRecognizerDelegate, ChatService {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public var delegate: AudioMessageDelegate!
    public var serviceType: ChatServiceType = .audioMessage
    
    private var COORDINATOR: ChatPageViewCoordinator!
    private var currentRecordingDuration: Float = 0
    private var CURRENT_USER: User!
    private var durationLabelTimer: Timer?
    private var GLOBAL_CONVERSATION: Conversation!
    
    //==================================================//
    
    /* MARK: - Constructor & Initialization Methods */
    
    public init(delegate: AudioMessageDelegate) throws {
        self.delegate = delegate
        super.init()
        
        guard syncDependencies() else { throw AudioMessageServiceError.failedToRetrieveDependencies }
    }
    
    @discardableResult
    private func syncDependencies() -> Bool {
        guard let coordinator = RuntimeStorage.coordinator,
              let currentUser = RuntimeStorage.currentUser,
              let globalConversation = RuntimeStorage.globalConversation else { return false }
        
        COORDINATOR = coordinator
        CURRENT_USER = currentUser
        GLOBAL_CONVERSATION = globalConversation
        
        return true
    }
    
    //==================================================//
    
    /* MARK: - Audio Recording Methods */
    
    public func initiateRecording() {
        guard !SpeechService.shared.isRecording else {
            cancelRecording()
            return
        }
        
        guard PermissionService.recordPermissionStatus == .granted else {
            guard PermissionService.recordPermissionStatus == .unknown else {
                PermissionService.presentCTA(for: .recording) { }
                return
            }
            
            PermissionService.requestPermission(for: .recording) { status, exception in
                guard status == .granted else {
                    guard let exception else { self.presentCTA(forRecording: true); return }
                    self.logError(exception, showAlert: true)
                    return
                }
                
                self.initiateRecording()
            }
            
            return
        }
        
        showRecordingUI { exception in
            guard exception == nil else {
                self.logError(exception!, showAlert: true)
                return
            }
            
            SpeechService.shared.startRecording { exception in
                guard let exception else { return }
                self.logError(exception, showAlert: true)
            }
        }
    }
    
    private func stopRecording(cancelled: Bool,
                               completion: @escaping(_ fileURL: URL?,
                                                     _ exception: Exception?) -> Void) {
        SpeechService.shared.stopRecording { fileURL, exception in
            AudioPlaybackController.resetAudioSession()
            
            guard let fileURL else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            if cancelled {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                } catch { completion(nil, Exception(error, metadata: [#file, #function, #line])) }
                
                self.currentRecordingDuration = 0
                self.delegate.messageInputBar.sendButton.isEnabled = false
                Core.gcd.after(seconds: 2) { self.addGestureRecognizers() }
            }
            
            self.hideRecordingUI {
                completion(cancelled ? nil : fileURL, nil)
            }
        }
    }
    
    public func finishRecording(progressHandler: @escaping() -> Void?,
                                completion: @escaping(_ inputFile: AudioFile?,
                                                      _ outputFile: AudioFile?,
                                                      _ translation: Translator.Translation?,
                                                      _ exception: Exception?) -> Void) {
        stopRecording(cancelled: false) { fileURL, exception in
            guard let fileURL else {
                completion(nil, nil, nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            progressHandler()
            
            self.processRecordedMedia(at: fileURL) {
                ChatServices.defaultDeliveryService?.incrementDeliveryProgress(by: 0.2)
            } completion: { inputFile, outputFile, translation, exception in
                guard let inputFile, let outputFile, let translation else {
                    completion(nil, nil, nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                completion(inputFile, outputFile, translation, nil)
            }
        }
    }
    
    private func cancelRecording() {
        cancelRecording { exception in
            guard let exception else { return }
            self.logError(exception, showAlert: false)
        }
    }
    
    private func cancelRecording(completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        stopRecording(cancelled: true) { _, exception in
            completion(exception)
        }
    }
    
    //==================================================//
    
    /* MARK: - UI State Methods */
    
    private func showRecordingUI(completion: @escaping(_ exception: Exception?) -> Void) {
        guard let recordingViewComponents = getRecordingViewComponents() else {
            completion(Exception("Couldn't unwrap recording view elements.", metadata: [#file, #function, #line]))
            return
        }
        
        let recordingView = recordingViewComponents.view
        let cancelLabel = recordingViewComponents.cancelLabel
        let durationLabel = recordingViewComponents.durationLabel
        let recordingImageView = recordingViewComponents.recordingImageView
        
        delegate.messageInputBar.contentView.addSubview(recordingView)
        recordingView.center = delegate.messageInputBar.inputTextView.center
        recordingView.tag = Core.ui.nameTag(for: "recordingView")
        
        cancelLabel.center.y = recordingView.center.y
        durationLabel.center.y = recordingView.center.y
        recordingImageView.center.y = recordingView.center.y
        durationLabel.center.y = recordingImageView.center.y
        
        UIView.animate(withDuration: 0.3) {
            self.delegate.messageInputBar.inputTextView.alpha = 0
            recordingView.alpha = 1
        }
        
        let offset = cancelLabel.intrinsicContentSize.width + 10
        let maxXToOffset = recordingView.frame.maxX - offset
        
        UIView.animate(withDuration: 0.3,
                       delay: 0,
                       options: [.curveEaseIn]) {
            let distanceFromMax = cancelLabel.frame.origin.x - maxXToOffset
            for _ in 0...Int(distanceFromMax) {
                guard cancelLabel.frame.origin.x != maxXToOffset else { return }
                cancelLabel.frame.origin.x -= 1
            }
        } completion: { _ in
            cancelLabel.frame.origin.x = maxXToOffset
            cancelLabel.startShimmering()
            
            if self.durationLabelTimer != nil {
                self.durationLabelTimer?.invalidate()
                self.durationLabelTimer = nil
            }
            
            self.durationLabelTimer = Timer.scheduledTimer(timeInterval: 1,
                                                           target: self,
                                                           selector: #selector(self.animateRecording),
                                                           userInfo: nil,
                                                           repeats: true)
            completion(nil)
        }
    }
    
    private func hideRecordingUI(completion: @escaping() -> Void = { }) {
        let recordingView = delegate.messageInputBar.contentView.subview(for: "recordingView")
        
        UIView.animate(withDuration: 0.2) {
            self.delegate.messageInputBar.inputTextView.alpha = 1
            if let recordingView { recordingView.alpha = 0 }
        } completion: { _ in
            self.delegate.messageInputBar.contentView.removeSubview(Core.ui.nameTag(for: "recordingView"),
                                                                    animated: false)
            if let recordingView { recordingView.removeFromSuperview() }
            completion()
        }
    }
    
    public func removeRecordingUI(completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        Core.hud.hide()
        
        hideRecordingUI {
            guard SpeechService.shared.isRecording else { completion(nil); return }
            self.stopRecording(cancelled: true) { _, exception in
                completion(exception)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Media Processing  */
    
    private func generateOutputFile(for translation: Translator.Translation,
                                    completion: @escaping(_ outputFile: AudioFile?,
                                                          _ exception: Exception?) -> Void) {
        SpeechService.shared.readToM4A(text: translation.output,
                                       language: translation.languagePair.to) { fileURL, exception in
            guard let fileURL else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            let outputFile = try? AudioFile(fromURL: fileURL)
            guard let outputFile else {
                completion(nil, Exception("Failed to generate output audio file.", metadata: [#file, #function, #line]))
                return
            }
            
            completion(outputFile, nil)
        }
    }
    
    /** Transcribes and translates the audio content of the recorded file. */
    private func getTranslationForInputFile(at url: URL,
                                            progressHandler: @escaping() -> Void?,
                                            completion: @escaping(_ translation: Translator.Translation?,
                                                                  _ exception: Exception?) -> Void) {
        syncDependencies()
        
        guard let currentUserLanguage = CURRENT_USER.languageCode,
              let otherUserLanguage = GLOBAL_CONVERSATION.otherUser?.languageCode ?? RuntimeStorage.messagesVC?.recipientBar?.selectedContactPair?.numberPairs?.users.first?.languageCode else {
            completion(nil, Exception("Couldn't determine language pair.", metadata: [#file, #function, #line]))
            return
        }
        
        let languagePair = Translator.LanguagePair(from: currentUserLanguage, to: otherUserLanguage)
        transcribeAndTranslate(forInputFile: url,
                               languagePair: languagePair,
                               progressHandler: progressHandler) { translation, exception in
            guard let translation else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(translation, nil)
        }
    }
    
    private func processInputFile(at url: URL,
                                  progressHandler: @escaping() -> Void?,
                                  completion: @escaping(_ outputFile: AudioFile?,
                                                        _ translation: Translator.Translation?,
                                                        _ exception: Exception?) -> Void) {
        getTranslationForInputFile(at: url,
                                   progressHandler: progressHandler) { translation, exception in
            guard let translation else {
                completion(nil, nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            progressHandler()
            
            guard translation.languagePair.from != translation.languagePair.to else {
                var inputFile = try! AudioFile(fromURL: url)
                inputFile.name = "output"
                
                completion(inputFile, translation, nil)
                return
            }
            
            self.retrieveOutputFile(for: translation) { outputFile, exception in
                guard let outputFile else {
                    completion(nil, nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                completion(outputFile, translation, nil)
            }
        }
    }
    
    private func processRecordedMedia(at url: URL,
                                      progressHandler: @escaping() -> Void,
                                      completion: @escaping(_ inputFile: AudioFile?,
                                                            _ outputFile: AudioFile?,
                                                            _ translation: Translator.Translation?,
                                                            _ exception: Exception?) -> Void) {
        guard let inputFile = try? AudioFile(fromURL: url) else {
            completion(nil, nil, nil, Exception("Failed to generate input audio file.",
                                                metadata: [#file, #function, #line]))
            return
        }
        
        self.processInputFile(at: url,
                              progressHandler: progressHandler) { outputFile, translation, exception in
            guard let outputFile, let translation else {
                completion(nil, nil, nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(inputFile, outputFile, translation, nil)
        }
    }
    
    private func retrieveOutputFile(for translation: Translator.Translation,
                                    completion: @escaping(_ outputFile: AudioFile?,
                                                          _ exception: Exception?) -> Void) {
        AudioMessageSerializer.shared.getPreRecordedOutputFile(for: translation) { outputFile, exception in
            guard let outputFile else {
                self.generateOutputFile(for: translation) { outputFile, exception in
                    guard let outputFile else {
                        completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                        return
                    }
                    
                    completion(outputFile, nil)
                }
                
                return
            }
            
            completion(outputFile, nil)
        }
    }
    
    private func transcribeAndTranslate(forInputFile atURL: URL,
                                        languagePair: Translator.LanguagePair,
                                        progressHandler: @escaping() -> Void?,
                                        completion: @escaping(_ translation: Translator.Translation?,
                                                              _ exception: Exception?) -> Void) {
        syncDependencies()
        
        SpeechService.shared.transcribeAudio(url: atURL,
                                             languageCode: languagePair.from) { transcription, exception in
            guard let transcription else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            ChatServices.defaultDeliveryService?.startAnimatingDelivery()
            ChatServices.defaultChatUIService?.hideNewChatControls()
            if let inputFile = try? AudioFile(fromURL: atURL) {
                ChatServices.defaultDeliveryService?.appendMockMessage(audio: inputFile)
            }
            progressHandler()
            
            FirebaseTranslator.shared.translate(Translator.TranslationInput(transcription),
                                                with: languagePair) { translation, exception in
                guard let translation else {
                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                completion(translation, nil)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Helper Methods */
    
    public func addGestureRecognizers() {
        syncDependencies()
        
        let sendButton = delegate.messageInputBar.sendButton
        guard sendButton.isRecordButton else { return }
        
        defer { sendButton.isEnabled = COORDINATOR.shouldEnableSendButton }
        
        guard CURRENT_USER.canSendAudioMessages else {
            let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(presentAudioMessagesUnsupportedAlert))
            addOrEnableRecognizer(singleTapGesture)
            return
        }
        
        // #warning("Is this ever used?")
        if let otherUser = GLOBAL_CONVERSATION.otherUser {
            guard Capabilities.textToSpeechSupported(for: otherUser.languageCode) else {
                guard !RuntimeStorage.acknowledgedAudioMessagesUnsupported! else { return }
                let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(presentAudioMessagesUnsupportedAlert))
                addOrEnableRecognizer(singleTapGesture)
                return
            }
        }
        
        guard PermissionService.recordPermissionStatus == .granted,
              PermissionService.transcribePermissionStatus == .granted else {
            let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(requestPermissions))
            addOrEnableRecognizer(singleTapGesture)
            return
        }
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPress))
        longPressGesture.minimumPressDuration = 0.3
        addOrEnableRecognizer(longPressGesture)
        
        let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(showRecordToast))
        addOrEnableRecognizer(singleTapGesture)
    }
    
    private func addOrEnableRecognizer(_ recognizer: UIGestureRecognizer) {
        let sendButton = delegate.messageInputBar.sendButton
        if sendButton.gestureRecognizers == nil || !sendButton.gestureRecognizers!.contains(where: { $0 == recognizer }) {
            sendButton.addGestureRecognizer(recognizer)
        } else {
            sendButton.gestureRecognizers?.first(where: { $0 == recognizer })?.isEnabled = true
        }
    }
    
    private func logError(_ exception: Exception,
                          showAlert: Bool) {
        syncDependencies()
        
        delegate.messageInputBar.sendButton.stopAnimating()
        delegate.messageInputBar.sendButton.isEnabled = (showAlert && COORDINATOR.shouldEnableSendButton)
        
        let filterParams: [JRException] = [.cannotOpenFile, .noAudioRecorderToStop, .noSpeechDetected, .retry]
        let passesFilter = !exception.isEqual(toAny: filterParams)
        
        Logger.log(exception,
                   with: (showAlert && passesFilter) ? .toast(icon: .micSlash) : .none,
                   verbose: exception.isEqual(to: .noAudioRecorderToStop))
        
        guard let componentService = ChatServices.chatUIService,
              !componentService.isUserCancellationEnabled else { return }
        componentService.setUserCancellation(enabled: true)
    }
    
    public func playVibration() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        Core.gcd.after(milliseconds: 50) {
            generator.impactOccurred()
            Core.gcd.after(milliseconds: 50) { generator.impactOccurred() }
        }
    }
    
    private func presentCTA(forRecording: Bool) {
        syncDependencies()
        
        DispatchQueue.main.async { self.delegate.messageInputBar.sendButton.isEnabled = false }
        Core.gcd.after(milliseconds: 500) {
            let shouldShowKeyboard = self.delegate.messageInputBar.inputTextView.isFirstResponder
            PermissionService.presentCTA(for: forRecording ? .recording : .transcription,
                                         sender: self.delegate.messageInputBar.sendButton) {
                RuntimeStorage.messagesVC?.becomeFirstResponder()
                if shouldShowKeyboard { self.delegate.messageInputBar.inputTextView.becomeFirstResponder() }
                self.delegate.messageInputBar.sendButton.isEnabled = self.COORDINATOR.shouldEnableSendButton
            }
        }
    }
    
    public func removeGestureRecognizers() {
        delegate.messageInputBar.sendButton.gestureRecognizers?.removeAll()
    }
    
    private func requestTranscribePermission() {
        guard PermissionService.transcribePermissionStatus == .granted else {
            PermissionService.requestPermission(for: .transcription) { status, exception in
                guard status == .granted else {
                    guard let exception else { self.presentCTA(forRecording: false); return }
                    Logger.log(exception, with: .errorAlert)
                    return
                }
                
                Core.gcd.after(milliseconds: 100) { self.addGestureRecognizers() }
            }
            
            return
        }
    }
    
    //==================================================//
    
    /* MARK: - Objective-C Exposed Methods */
    
    @objc
    private func animateRecording() {
        guard SpeechService.shared.isRecording,
              delegate.messageInputBar.sendButton.isRecordButton,
              let recordingView = delegate.messageInputBar.contentView.subview(for: "recordingView"),
              let durationLabel = recordingView.subview(for: "durationLabel") as? UILabel,
              let recordingImageView = recordingView.subview(for: "recordingImageView") as? UIImageView else {
            durationLabelTimer?.invalidate()
            durationLabelTimer = nil
            currentRecordingDuration = 0
            return
        }
        
        currentRecordingDuration += 1
        
        durationLabel.text = currentRecordingDuration.durationString
        durationLabel.frame.size.width = durationLabel.intrinsicContentSize.width
        
        let recordingImage = UIImage(named: "Recording")
        let recordingImageFilled = UIImage(named: "Recording (Filled)")
        
        UIView.transition(with: recordingImageView,
                          duration: 0.2,
                          options: [.transitionCrossDissolve]) {
            switch recordingImageView.image {
            case recordingImage:
                recordingImageView.image = recordingImageFilled
            case recordingImageFilled:
                recordingImageView.image = recordingImage
            default:
                return
            }
        }
    }
    
    @objc
    private func longPress(recognizer: UILongPressGestureRecognizer) {
        Core.hud.hide()
        let inputBar = delegate.messageInputBar
        
        switch recognizer.state {
        case .began:
            inputBar.delegate?.inputBar(inputBar, didPressSendButtonWith: "START_RECORDING")
        case .ended:
            inputBar.sendButton.isEnabled = false
            inputBar.delegate?.inputBar(inputBar, didPressSendButtonWith: "STOP_RECORDING")
            
            guard SpeechService.shared.isRecording else {
                Core.gcd.after(milliseconds: 500) { inputBar.delegate?.inputBar(inputBar, didPressSendButtonWith: "STOP_RECORDING") }
                return
            }
        case .changed:
            let point = recognizer.location(in: delegate.view)
            let convertedPoint = delegate.view.convert(point, to: inputBar.sendButton)
            guard !inputBar.sendButton.bounds.contains(convertedPoint),
                  SpeechService.shared.isRecording else { return }
            
            inputBar.sendButton.isEnabled = false
            inputBar.delegate?.inputBar(inputBar, didPressSendButtonWith: "CANCEL_RECORDING")
        default:
            return
        }
    }
    
    @objc
    private func presentAudioMessagesUnsupportedAlert() {
        syncDependencies()
        
        let alert = AKAlert(message: "Audio messages are unsupported for your language.\n\nPlease check back later in a future update!",
                            cancelButtonTitle: "OK",
                            sender: delegate.messageInputBar.sendButton)
        
        let shouldShowKeyboard = delegate.messageInputBar.inputTextView.isFirstResponder
        alert.present { _ in
            RuntimeStorage.store(true, as: .acknowledgedAudioMessagesUnsupported)
            UserDefaults.standard.set(true, forKey: "acknowledgedAudioMessagesUnsupported")
            
            self.removeGestureRecognizers()
            ChatServices.defaultChatUIService?.configureInputBar(forRecord: false)
            self.delegate.messageInputBar.sendButton.isEnabled = self.COORDINATOR.shouldEnableSendButton
            
            Core.gcd.after(milliseconds: 500) {
                guard shouldShowKeyboard else {
                    RuntimeStorage.messagesVC?.becomeFirstResponder()
                    return
                }
                
                self.delegate.messageInputBar.inputTextView.becomeFirstResponder()
            }
        }
    }
    
    @objc
    private func requestPermissions() {
        guard PermissionService.recordPermissionStatus == .granted else {
            PermissionService.requestPermission(for: .recording) { status, exception in
                guard status == .granted else {
                    guard let exception else { self.presentCTA(forRecording: true); return }
                    Logger.log(exception, with: .errorAlert)
                    return
                }
                
                self.requestTranscribePermission()
            }
            
            return
        }
        
        self.requestTranscribePermission()
    }
    
    @objc
    private func showRecordToast() {
        cancelRecording()
        Core.hud.flash(LocalizedString.holdDownToRecord, image: .mic)
        delegate.messageInputBar.sendButton.isEnabled = COORDINATOR.shouldEnableSendButton
    }
    
    //==================================================//
    
    /* MARK: - View Builders */
    
    private func getCancelLabel() -> UILabel {
        let cancelLabel = UILabel()
        cancelLabel.text = "< \(LocalizedString.slideToCancel)"
        
        cancelLabel.baselineAdjustment = .alignCenters
        cancelLabel.font = UIFont(name: "SFUIText-Semibold", size: 17)
        cancelLabel.textAlignment = .center
        cancelLabel.textColor = .gray
        
        cancelLabel.frame.size.width = cancelLabel.intrinsicContentSize.width
        cancelLabel.frame.size.height = 20
        
        return cancelLabel
    }
    
    private func getDurationLabel() -> UILabel {
        let durationLabel = UILabel()
        durationLabel.text = "0:00"
        
        durationLabel.baselineAdjustment = .alignCenters
        durationLabel.font = UIFont(name: "SFUIText-Semibold", size: 17)
        durationLabel.textAlignment = .center
        durationLabel.textColor = .gray
        
        durationLabel.frame.size.width = durationLabel.intrinsicContentSize.width
        durationLabel.frame.size.height = 20
        
        return durationLabel
    }
    
    private func getRecordingImageView() -> UIImageView {
        let recordingImageView = UIImageView()
        recordingImageView.frame = CGRect(origin: .zero, size: CGSize(width: 30, height: 30))
        recordingImageView.image = UIImage(named: "Recording")
        
        return recordingImageView
    }
    
    private func getRecordingViewComponents() -> (view: UIView,
                                                  cancelLabel: UILabel,
                                                  durationLabel: UILabel,
                                                  recordingImageView: UIImageView)? {
        /* Enclosing View Setup */
        let recordingView = UIView()
        recordingView.backgroundColor = delegate.messageInputBar.inputTextView.backgroundColor
        recordingView.frame = delegate.messageInputBar.inputTextView.frame
        
        recordingView.clipsToBounds = true
        recordingView.layer.borderColor = UIColor.systemGray.cgColor
        recordingView.layer.borderWidth = 0.5
        recordingView.layer.cornerRadius = 15
        
        /* Cancel Label Setup */
        let cancelLabel = getCancelLabel()
        recordingView.addSubview(cancelLabel)
        
        cancelLabel.frame.origin.x = recordingView.frame.maxX
        cancelLabel.tag = Core.ui.nameTag(for: "cancelLabel")
        
        /* Duration Label Setup */
        let durationLabel = getDurationLabel()
        recordingView.addSubview(durationLabel)
        
        durationLabel.frame.origin.x = recordingView.frame.origin.x + durationLabel.intrinsicContentSize.width
        durationLabel.tag = Core.ui.nameTag(for: "durationLabel")
        
        /* Image View Setup */
        let recordingImageView = getRecordingImageView()
        recordingView.addSubview(recordingImageView)
        
        recordingImageView.frame.origin.x = recordingView.frame.origin.x + 5
        recordingImageView.tag = Core.ui.nameTag(for: "recordingImageView")
        
        guard let cancelLabel = recordingView.subview(for: "cancelLabel") as? UILabel,
              let durationLabel = recordingView.subview(for: "durationLabel") as? UILabel,
              let recordingImageView = recordingView.subview(for: "recordingImageView") as? UIImageView else { return nil }
        
        return (view: recordingView,
                cancelLabel: cancelLabel,
                durationLabel: durationLabel,
                recordingImageView: recordingImageView)
    }
}

public enum AudioMessageServiceError: Error {
    case failedToRetrieveDependencies
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: - UIView */
private extension UIView {
    func startShimmering() {
        //        let light = UIColor.init(white: 0, alpha: 0.1).cgColor
        let light = UIColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        let dark = UIColor.black.cgColor
        
        let gradient: CAGradientLayer = CAGradientLayer()
        gradient.colors = [dark, light, dark]
        gradient.frame = CGRect(x: -self.bounds.size.width,
                                y: 0,
                                width: 3*self.bounds.size.width,
                                height: self.bounds.size.height)
        gradient.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1.0, y: 0.525)
        gradient.locations = [0.4, 0.5, 0.6]
        self.layer.mask = gradient
        
        let animation: CABasicAnimation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [0.0, 0.1, 0.2]
        animation.toValue = [0.8, 0.9, 1.0]
        
        animation.duration = 1.5
        animation.repeatCount = HUGE
        gradient.add(animation, forKey: "shimmer")
    }
    
    func stopShimmering() {
        self.layer.mask = nil
    }
}
