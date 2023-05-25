//
//  DeliveryService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 21/02/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/* Third-party Frameworks */
import InputBarAccessoryView
import Translator

public protocol DeliveryDelegate {
    func setConversation(_ conversation: Conversation)
}

public class DeliveryService: ChatService {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public var delegate: DeliveryDelegate!
    public var serviceType: ChatServiceType = .delivery
    
    private var COORDINATOR: ChatPageViewCoordinator!
    private var CURRENT_MESSAGE_SLICE: [Message]!
    private var CURRENT_USER: User!
    private var CURRENT_USER_ID: String!
    private var deliveryProgress: Float = 0.0 {
        didSet {
            guard deliveryTimer != nil,
                  deliveryProgress != 0 else { return }
            animateDeliveryProgression { wasHidden in
                guard wasHidden else { return }
                self.deliveryTimer?.invalidate()
                self.deliveryTimer = nil
                self.deliveryProgress = 0
            }
        }
    }
    private var deliveryTimer: Timer?
    
    //==================================================//
    
    /* MARK: - Constructor & Initialization Methods */
    
    public init(delegate: DeliveryDelegate) throws {
        self.delegate = delegate
        guard syncDependencies() else { throw DeliveryServiceError.failedToRetrieveDependencies }
    }
    
    @discardableResult
    private func syncDependencies() -> Bool {
        guard let coordinator = RuntimeStorage.coordinator,
              let currentMessageSlice = RuntimeStorage.currentMessageSlice,
              let currentUser = RuntimeStorage.currentUser,
              let currentUserID = RuntimeStorage.currentUserID else { return false }
        
        COORDINATOR = coordinator
        CURRENT_MESSAGE_SLICE = currentMessageSlice
        CURRENT_USER = currentUser
        CURRENT_USER_ID = currentUserID
        
        return true
    }
    
    //==================================================//
    
    /* MARK: - Conversation Metadata Handling */
    
    private func createConversationForNewMessage(completion: @escaping (_ conversation: Conversation?,
                                                                        _ exception: Exception?) -> Void) {
        syncDependencies()
        
        guard let user = ContactNavigationRouter.currentlySelectedUser else {
            completion(nil, Exception("No selected user!", metadata: [#file, #function, #line]))
            return
        }
        
        ConversationSerializer.shared.createConversation(between: [CURRENT_USER,
                                                                   user]) { conversation, exception in
            guard let conversation else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            AnalyticsService.logEvent(.createNewConversation,
                                      with: ["conversationIdKey": conversation.identifier.key!,
                                             "participants": conversation.participants.userIdPair])
            
            conversation.setOtherUser { exception in
                guard let exception else {
                    completion(conversation, nil)
                    return
                }
                
                completion(nil, exception)
            }
        }
    }
    
    private func updateConversationData(for newMessage: Message,
                                        timeout: Timeout? = nil,
                                        completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        syncDependencies()
        
        let conversation = COORDINATOR.conversation.wrappedValue
        conversation.updateLastModified()
        
        conversation.messages.removeAll(where: { $0.identifier == "NEW" })
        conversation.messages.append(newMessage)
        conversation.messages = conversation.messages.filteredAndSorted
        
        var exceptions = [Exception]()
        conversation.unHideForAllParticipants { unHideException in
            if let unHideException {
                exceptions.append(unHideException)
            }
            
            conversation.updateHash { updateHashException in
                if let updateHashException {
                    exceptions.append(updateHashException)
                }
                
                timeout?.cancel()
                RuntimeStorage.store(conversation, as: .globalConversation)
                
                self.CURRENT_MESSAGE_SLICE.removeAll(where: { $0.identifier == "NEW" })
                self.CURRENT_MESSAGE_SLICE.append(newMessage)
                RuntimeStorage.store(self.CURRENT_MESSAGE_SLICE!, as: .currentMessageSlice)
                
                print("Adding to archive \(conversation.identifier.key!) | \(conversation.identifier.hash!)")
                ConversationArchiver.addToArchive(conversation)
                
                if var openConversations = self.CURRENT_USER.openConversations {
                    openConversations.removeLast()
                    openConversations.append(conversation)
                    self.CURRENT_USER.openConversations = openConversations
                } else {
                    self.CURRENT_USER.openConversations = [conversation]
                }
                
                RuntimeStorage.store(true, as: .shouldReloadData)
                RuntimeStorage.store(false, as: .isSendingMessage)
                
                ContactNavigationRouter.currentlySelectedUser = nil
                
                Logger.closeStream()
                completion(exceptions.compiledException)
            }
        }
    }
    
    private func updateGlobalConversation(with conversation: Conversation) {
        syncDependencies()
        
        RuntimeStorage.store(conversation, as: .globalConversation)
        ConversationArchiver.addToArchive(conversation)
        
        if var openConversations = CURRENT_USER.openConversations {
            //            openConversations.removeLast()
            openConversations.append(conversation)
            RuntimeStorage.currentUser?.openConversations = openConversations
        } else {
            RuntimeStorage.currentUser?.openConversations = [conversation]
        }
        
        delegate.setConversation(conversation)
        COORDINATOR.setConversation(conversation)
    }
    
    //==================================================//
    
    /* MARK: - Mock Messages */
    
    public func appendMockMessage(text: String? = nil,
                                  audio: AudioFile? = nil) {
        syncDependencies()
        ChatServices.defaultChatUIService?.hideNewChatControls()
        
        let conversation = COORDINATOR.conversation.wrappedValue
        let mockMessage = generateMockMessage(text: text, audio: audio)
        
        conversation.messages.append(mockMessage)
        conversation.messages = conversation.messages.sorted(by: { $0.sentDate < $1.sentDate }) /*.sortedFilteredMessages()*/
        
        RuntimeStorage.store(conversation, as: .globalConversation)
        
        print("wrapped convo has \(conversation.messages.count)")
        print("global convo has \(RuntimeStorage.globalConversation!.messages.count)")
        
        CURRENT_MESSAGE_SLICE.append(mockMessage)
        RuntimeStorage.store(CURRENT_MESSAGE_SLICE!, as: .currentMessageSlice)
        
        if var openConversations = CURRENT_USER.openConversations {
            //            openConversations.removeLast()
            openConversations.append(conversation)
            CURRENT_USER.openConversations = openConversations
        } else {
            CURRENT_USER.openConversations = [conversation]
        }
        
        RuntimeStorage.store(true, as: .shouldReloadData)
    }
    
    private func generateMockMessage(text: String?,
                                     audio: AudioFile?) -> Message {
        syncDependencies()
        
        let wrappedConversation = COORDINATOR.conversation.wrappedValue
        let otherLanguageCode = wrappedConversation.otherUser?.languageCode ?? "en"
        
        let mockLanguagePair = LanguagePair(from: CURRENT_USER.languageCode, to: otherLanguageCode)
        let mockTranslation = Translation(input: TranslationInput(text ?? ""),
                                          output: "",
                                          languagePair: mockLanguagePair)
        
        var audioMessageReference: AudioMessageReference?
        if let audio {
            audioMessageReference = AudioMessageReference(directoryPath: "",
                                                          original: audio,
                                                          translated: audio)
        }
        
        return Message(identifier: "NEW",
                       fromAccountIdentifier: CURRENT_USER_ID,
                       languagePair: mockLanguagePair,
                       translation: mockTranslation,
                       readDate: nil,
                       sentDate: Date(),
                       hasAudioComponent: audio != nil,
                       audioComponent: audioMessageReference)
    }
    
    //==================================================//
    
    /* MARK: - Message Translation */
    
    private func debugTranslate(_ text: String,
                                progressHandler: @escaping() -> Void?,
                                completion: @escaping(_ translation: Translator.Translation?,
                                                      _ exception: Exception?) -> Void) {
        syncDependencies()
        
        guard let otherUser = COORDINATOR.conversation.wrappedValue.otherUser else {
            completion(nil, Exception("Other user has not been set.", metadata: [#file, #function, #line]))
            return
        }
        
        let debugLanguagePair = Translator.LanguagePair(from: "en", to: CURRENT_USER.languageCode)
        let finalLanguagePair = Translator.LanguagePair(from: CURRENT_USER.languageCode, to: otherUser.languageCode)
        
        translate(text, languagePair: debugLanguagePair) { translation, exception in
            guard let translation else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            progressHandler()
            
            self.translate(translation.output, languagePair: finalLanguagePair) { translation, exception in
                guard let translation else {
                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                completion(translation, nil)
            }
        }
    }
    
    private func translate(_ text: String,
                           languagePair: LanguagePair,
                           completion: @escaping(_ translation: Translation?,
                                                 _ exception: Exception?) -> Void) {
        let timeout = Timeout(after: 30) {
            completion(nil, Exception.timedOut([#file, #function, #line]))
        }
        
        FirebaseTranslator.shared.translate(TranslationInput(text),
                                            with: languagePair) { translation, exception in
            timeout.cancel()
            
            guard let translation else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(translation, nil)
        }
    }
    
    //==================================================//
    
    /* MARK: - Message Creation */
    
    private func createAudioMessage(inputFile: AudioFile,
                                    outputFile: AudioFile,
                                    translation: Translation,
                                    completion: @escaping(_ message: Message?,
                                                          _ exception: Exception?) -> Void) {
        syncDependencies()
        
        guard COORDINATOR.conversation.wrappedValue.identifier.key != "EMPTY" else {
            createConversationForNewMessage(completion: { conversation, exception in
                guard let conversation else {
                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                self.deliveryProgress += 0.2
                self.updateGlobalConversation(with: conversation)
                
                self.createAudioMessage(inputFile: inputFile,
                                        outputFile: outputFile,
                                        translation: translation) { message, exception in
                    completion(message, exception)
                    return
                }
            })
            
            return
        }
        
        //        appendMockMessage(audio: inputFile)
        createMessage(audioComponent: (input: inputFile, output: outputFile),
                      translation: translation) {
            self.deliveryProgress += 0.2
        } completion: { message, exception in
            self.deliveryProgress += 0.2
            completion(message, exception)
        }
    }
    
    private func createTextMessage(text: String,
                                   completion: @escaping(_ message: Message?,
                                                         _ exception: Exception?) -> Void) {
        syncDependencies()
        
        Logger.openStream(metadata: [#file, #function, #line])
        
        guard COORDINATOR.conversation.wrappedValue.identifier.key != "EMPTY" else {
            createConversationForNewMessage { conversation, exception in
                guard let conversation else {
                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                self.deliveryProgress += 0.2
                self.updateGlobalConversation(with: conversation)
                self.COORDINATOR.setConversation(conversation)
                
                self.createTextMessage(text: text) { message, exception in
                    completion(message, exception)
                }
            }
            
            return
        }
        
        appendMockMessage(text: text)
        
        guard let otherUser = COORDINATOR.conversation.wrappedValue.otherUser else {
            completion(nil, Exception("Other user has not been set.", metadata: [#file, #function, #line]))
            return
        }
        
        let languagePair = Translator.LanguagePair(from: CURRENT_USER.languageCode,
                                                   to: otherUser.languageCode)
        
        //        guard !Build.developerModeEnabled else {
        //            debugTranslate(text) {
        //                self.deliveryProgress += 0.2
        //            } completion: { translation, exception in
        //                guard let translation else {
        //                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
        //                    return
        //                }
        //
        //                self.deliveryProgress += 0.2
        //                self.createMessage(translation: translation) {
        //                    self.deliveryProgress += 0.2
        //                } completion: { message, exception in
        //                    self.deliveryProgress += 0.2
        //                    completion(message, exception)
        //                }
        //            }
        //
        //            return
        //        }
        
        translate(text, languagePair: languagePair) { translation, exception in
            guard let translation else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            self.deliveryProgress += 0.2
            self.createMessage(translation: translation) {
                self.deliveryProgress += 0.2
            } completion: { message, exception in
                self.deliveryProgress += 0.2
                completion(message, exception)
            }
        }
    }
    
    private func createMessage(audioComponent: (input: AudioFile, output: AudioFile)? = nil,
                               translation: Translation,
                               progressHandler: @escaping() -> Void?,
                               completion: @escaping(_ message: Message?,
                                                     _ exception: Exception?) -> Void) {
        syncDependencies()
        
        let conversation = COORDINATOR.conversation.wrappedValue
        guard conversation.identifier.key != "EMPTY" else {
            completion(nil, Exception("No conversation to send message in.", metadata: [#file, #function, #line]))
            return
        }
        
        MessageSerializer.shared.createMessage(fromAccountWithIdentifier: CURRENT_USER_ID,
                                               inConversationWithIdentifier: conversation.identifier.key,
                                               translation: translation,
                                               audioComponent: audioComponent) { returnedMessage, exception in
            guard let returnedMessage else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            progressHandler()
            
            AnalyticsService.logEvent(returnedMessage.hasAudioComponent ? .sendAudioMessage : .sendTextMessage,
                                      with: ["conversationIdKey": self.COORDINATOR.conversation.wrappedValue.identifier.key!,
                                             "languagePair": translation.languagePair.asString(),
                                             "messageId": returnedMessage.identifier!])
            
            guard returnedMessage.hasAudioComponent else {
                completion(returnedMessage, nil)
                return
            }
            
            AudioMessageSerializer.shared.retrieveAudioReference(for: returnedMessage) { messageWithAudioComponent, exception in
                guard exception == nil,
                      messageWithAudioComponent.audioComponent != nil else {
                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                completion(messageWithAudioComponent, nil)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Message Delivery */
    
    public func sendAudioMessage(inputFile: AudioFile,
                                 outputFile: AudioFile,
                                 translation: Translation,
                                 completion: @escaping(_ exception: Exception?) -> Void) {
        syncDependencies()
        ChatServices.defaultMenuControllerService?.stopSpeakingIfNeeded()
        
        let previousConversationCount = CURRENT_USER.openConversations?.count ?? 0
        
        createAudioMessage(inputFile: inputFile,
                           outputFile: outputFile,
                           translation: translation) { message, exception in
            guard let message else {
                self.stopAnimatingDelivery()
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            self.updateConversationData(for: message,
                                        timeout: Timeout(after: 30),
                                        completion: { exception in
                Core.hud.hide(delay: 1)
                self.COORDINATOR.conversation.otherUser.wrappedValue?.notifyOfNewMessage(.audioMessage)
                
                ChatServices.defaultChatUIService?.setUserCancellation(enabled: true)
                RuntimeStorage.messagesVC?.messageInputBar.sendButton.stopAnimating()
                RuntimeStorage.messagesVC?.messageInputBar.sendButton.isEnabled = self.COORDINATOR.shouldEnableSendButton
                
                /* Don't need to call stopAnimatingDelivery() as animateDeliveryProgression()
                 will hide and destroy the timer for us by setting it to 1 */
                self.deliveryProgress = 1
                
                if previousConversationCount == 0 {
                    RuntimeStorage.store(true, as: .shouldReloadForFirstOrNewConversation)
                    RuntimeStorage.store(true, as: .shouldShowMenuForFirstMessage)
                }
                
                completion(exception)
            })
        }
    }
    
    public func sendTextMessage(text: String,
                                completion: @escaping(_ exception: Exception?) -> Void) {
        syncDependencies()
        startAnimatingDelivery()
        ChatServices.defaultMenuControllerService?.stopSpeakingIfNeeded()
        
        let previousConversationCount = CURRENT_USER.openConversations?.count ?? 0
        
        createTextMessage(text: text) { message, exception in
            guard let message else {
                self.stopAnimatingDelivery()
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            self.updateConversationData(for: message,
                                        timeout: Timeout(after: 30)) { exception in
                Core.hud.hide(delay: 1)
                self.COORDINATOR.conversation.otherUser.wrappedValue?.notifyOfNewMessage(.textMessage(content: message.translation.output))
                
                ChatServices.defaultChatUIService?.setUserCancellation(enabled: true)
                RuntimeStorage.messagesVC?.messageInputBar.sendButton.stopAnimating()
                RuntimeStorage.messagesVC?.messageInputBar.sendButton.isEnabled = self.COORDINATOR.shouldEnableSendButton
                
                /* Don't need to call stopAnimatingDelivery() as animateDeliveryProgression()
                 will hide and destroy the timer for us by setting it to 1 */
                self.deliveryProgress = 1
                
                if previousConversationCount == 0 {
                    RuntimeStorage.store(true, as: .shouldReloadForFirstOrNewConversation)
                    RuntimeStorage.store(true, as: .shouldShowMenuForFirstMessage)
                }
                
                completion(exception)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Delivery Progression (UI) */
    
    private func animateDeliveryProgression(completion: @escaping(_ wasHidden: Bool) -> Void = { _ in }) {
        guard deliveryProgress < 1 else {
            DispatchQueue.main.async {
                RuntimeStorage.messagesVC?.progressView?.setProgress(1, animated: true)
                
                UIView.animate(withDuration: 0.2,
                               delay: 1,
                               options: []) {
                    RuntimeStorage.messagesVC?.progressView?.alpha = 0
                } completion: { _ in
                    Core.gcd.after(seconds: 1) {
                        RuntimeStorage.messagesVC?.progressView?.progress = 0
                        completion(true)
                    }
                }
            }
            
            return
        }
        
        DispatchQueue.main.async {
            RuntimeStorage.messagesVC?.progressView?.alpha = 1
            RuntimeStorage.messagesVC?.progressView?.setProgress(self.deliveryProgress, animated: true)
            completion(false)
        }
    }
    
    /// Allows the audio message controller to increment the progress bar while processing recorded media
    public func incrementDeliveryProgress(by: Float) {
        DispatchQueue.main.async {
            self.deliveryProgress += by
        }
    }
    
    @objc
    private func incrementProgress() {
        guard let deliveryTimer, deliveryTimer.isValid else { return }
        
        guard deliveryProgress + 0.001 < 0.9 else { return }
        deliveryProgress += 0.001
    }
    
    public func startAnimatingDelivery() {
        DispatchQueue.main.async {
            guard self.deliveryTimer == nil else { return }
            self.deliveryProgress = 0
            self.deliveryTimer = Timer.scheduledTimer(timeInterval: 0.01,
                                                      target: self,
                                                      selector: #selector(self.incrementProgress),
                                                      userInfo: nil,
                                                      repeats: true)
        }
    }
    
    private func stopAnimatingDelivery() {
        deliveryTimer?.invalidate()
        deliveryTimer = nil
        
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.2,
                           delay: 0.5,
                           options: []) {
                RuntimeStorage.messagesVC?.progressView?.alpha = 0
            } completion: { _ in
                Core.gcd.after(seconds: 1) { RuntimeStorage.messagesVC?.progressView?.progress = 0 }
                self.deliveryProgress = 0
            }
        }
    }
}

public enum DeliveryServiceError: Error {
    case failedToRetrieveDependencies
}
