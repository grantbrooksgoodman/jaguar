//
//  RetranslationService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/01/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/* Third-party Frameworks */
import MessageKit
import Translator

public protocol RetranslationDelegate {
    var messagesCollectionView: MessagesCollectionView { get }
}

public class RetranslationService: ChatService {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Users
    private var CURRENT_USER: User!
    private var OTHER_USER: User!
    
    // Other
    public var delegate: RetranslationDelegate!
    public var serviceType: ChatServiceType = .retranslation
    
    private(set) var isRetranslating = false
    
    private var CURRENT_MESSAGE_SLICE: [Message]!
    private var CURRENT_USER_ID: String!
    private var GLOBAL_CONVERSATION: Conversation!
    private var selectedCell: MessageContentCell?
    private var selectedMessage: Message?
    private var selectedSection: Int?
    
    //==================================================//
    
    /* MARK: - Constructor & Initialization Methods */
    
    public init(delegate: RetranslationDelegate) throws {
        self.delegate = delegate
        guard syncDependencies() else { throw RetranslationServiceError.failedToRetrieveDependencies }
    }
    
    @discardableResult
    private func syncDependencies() -> Bool  {
        guard let globalConversation = RuntimeStorage.globalConversation,
              let currentUser = RuntimeStorage.currentUser,
              let currentUserID = RuntimeStorage.currentUserID,
              let currentMessageSlice = RuntimeStorage.currentMessageSlice,
              let otherUser = globalConversation.otherUser else { return false }
        
        GLOBAL_CONVERSATION = globalConversation
        CURRENT_USER = currentUser
        CURRENT_USER_ID = currentUserID
        CURRENT_MESSAGE_SLICE = currentMessageSlice
        OTHER_USER = otherUser
        
        return true
    }
    
    //==================================================//
    
    /* MARK: - Public Methods */
    
    public func retryTranslation(forCell cell: MessageContentCell) {
        // delete the translation on the server and from archive
        // retry with google, then with deepL
        // if unable alert, if got it then reload with new translation
        // the hashes will remain the same because it's the same input value.
        
        syncDependencies()
        guard CURRENT_MESSAGE_SLICE.count > cell.tag else { return }
        
        let currentMessage = CURRENT_MESSAGE_SLICE[cell.tag]
        let message = correctLanguagePair(for: currentMessage)
        
        let translation = message.translation!
        guard translation.input.value() == translation.output else { return }
        
        selectedCell = cell
        selectedMessage = message
        selectedSection = cell.tag
        
        Logger.log("Wants to retry translation on message from \(translation.languagePair.from) to \(translation.languagePair.to).",
                   metadata: [#file, #function, #line])
        
        Core.hud.showProgress()
        
        isRetranslating = true
        TranslationSerializer.removeTranslation(for: translation.input,
                                                languagePair: translation.languagePair) { exception in
            guard exception == nil else {
                self.logError(exception!, showAlert: false)
                return
            }
            
            TranslationArchiver.clearArchive()
            
            Logger.openStream(message: "Retrying translation using Google...",
                              metadata: [#file, #function, #line])
            self.retryTranslationUsingGoogle(translation)
        }
    }
    
    //==================================================//
    
    /* MARK: - Message Retranslation */
    
    // - MARK: Step 1
    
    private func retryTranslationUsingGoogle(_ translation: Translation) {
        retryTranslation(translation,
                         using: .google) { newTranslation, exception in
            guard let newTranslation else {
                let error = exception ?? Exception(metadata: [#file, #function, #line])
                
                guard error.descriptor != "Translation result is still the same." else {
                    Logger.logToStream("Same translation – trying DeepL...",
                                       line: #line)
                    
                    self.retryTranslationUsingDeepL(translation)
                    return
                }
                
                self.logError(error, showAlert: false)
                return
            }
            
            Logger.closeStream(message: "Got proper translation from Google!",
                               onLine: #line)
            
            self.displayRetranslation(newTranslation)
        }
    }
    
    // - MARK: Step 2
    
    private func retryTranslationUsingDeepL(_ translation: Translation) {
        TranslationSerializer.removeTranslation(for: translation.input,
                                                languagePair: translation.languagePair) { exception in
            guard exception == nil else {
                self.logError(exception!, showAlert: false)
                return
            }
            
            self.retryTranslation(translation,
                                  using: .deepL) { newTranslation, exception in
                guard let newTranslation else {
                    let error = exception ?? Exception(metadata: [#file, #function, #line])
                    
                    guard error.descriptor != "Translation result is still the same." else {
                        Logger.logToStream("Same translation – trying English method...",
                                           line: #line)
                        
                        self.retryTranslationUsingEnglishMethod(translation)
                        return
                    }
                    
                    self.logError(error, showAlert: false)
                    return
                }
                
                Logger.closeStream(message: "Got proper translation from DeepL!",
                                   onLine: #line)
                
                self.displayRetranslation(newTranslation)
            }
        }
    }
    
    // - MARK: Step 3
    
    private func retryTranslationUsingEnglishMethod(_ translation: Translation) {
        let originalLanguagePair = translation.languagePair
        
        TranslationSerializer.removeTranslation(for: translation.input,
                                                languagePair: translation.languagePair) { exception in
            guard exception == nil else {
                self.logError(exception!, showAlert: false)
                return
            }
            
            TranslationArchiver.clearArchive()
            
            FirebaseTranslator.shared.translate(translation.input,
                                                with: LanguagePair(from: originalLanguagePair.from, to: "en")) { toEnglish, exception in
                guard let toEnglish else {
                    self.logError(exception ?? Exception(metadata: [#file, #function, #line]),
                                  showAlert: false)
                    return
                }
                
                FirebaseTranslator.shared.translate(TranslationInput(toEnglish.output),
                                                    with: LanguagePair(from: "en", to: originalLanguagePair.to)) { toDesired, exception in
                    guard let toDesired else {
                        self.logError(exception ?? Exception(metadata: [#file, #function, #line]),
                                      showAlert: false)
                        return
                    }
                    
                    self.finishRetranslationUsingEnglishMethod(translation, toDesired)
                }
            }
        }
    }
    
    // - MARK: Step 4
    
    private func finishRetranslationUsingEnglishMethod(_ original: Translation,
                                                       _ toDesired: Translation) {
        let originalLanguagePair = original.languagePair
        let desiredString = Locale.current.localizedString(forIdentifier: originalLanguagePair.to)
        
        guard let language = RecognitionService.detectedLanguage(for: toDesired.output) else {
            logError(Exception("Couldn't detect language from output.",
                               metadata: [#file, #function, #line]),
                     showAlert: false)
            return
        }
        
        guard language == originalLanguagePair.to else {
            let detectedString = Locale.current.localizedString(forIdentifier: language)
            
            Logger.closeStream(message: "English method yielded wrong language output.\nDesired: \(desiredString ?? "")\nGot: \(detectedString ?? "")\nOriginally From: \(originalLanguagePair.from)\nInput: \(original.input.value())\nOutput: \(toDesired.output)",
                               onLine: #line)
            
            TranslationSerializer.removeTranslation(for: original.input,
                                                    languagePair: originalLanguagePair)
            
            TranslationSerializer.removeTranslation(for: toDesired.input,
                                                    languagePair: toDesired.languagePair)
            
            logError(Exception("Failed to retranslate.",
                               metadata: [#file, #function, #line]),
                     showAlert: false)
            
            Core.gcd.after(seconds: 1) {
                Core.hud.flash(LocalizedString.failedToRetranslate, image: .exclamation)
            }
            
            return
        }
        
        Logger.logToStream("Desired: \(desiredString ?? "")\nOriginally From: \(originalLanguagePair.from)\nInput: \(original.input.value())\nOutput: \(toDesired.output)",
                           line: #line)
        
        let mutantTranslation = Translation(input: original.input,
                                            output: toDesired.output.matchingCapitalization(of: original.input.value()),
                                            languagePair: originalLanguagePair)
        
        TranslationSerializer.uploadTranslation(mutantTranslation)
        TranslationArchiver.addToArchive(mutantTranslation)
        
        Logger.closeStream(message: "Got proper translation from English method!",
                           onLine: #line)
        self.displayRetranslation(mutantTranslation)
    }
    
    // - MARK: Step 5
    
    private func displayRetranslation(_ translation: Translation) {
        syncDependencies()
        
        Core.hud.hide()
        
        guard let selectedMessage,
              let selectedSection else { return }
        
        selectedMessage.translation = translation
        selectedMessage.languagePair = translation.languagePair
        
        selectedMessage.updateLanguagePair(translation.languagePair) { exception in
            guard exception == nil else {
                self.logError(exception!, showAlert: false)
                return
            }
            
            let storedMessage = self.GLOBAL_CONVERSATION.messages.filter({ $0.identifier == selectedMessage.identifier }).first!
            storedMessage.translation = translation
            storedMessage.languagePair = translation.languagePair
            
            let sliceMessage = self.CURRENT_MESSAGE_SLICE.filter({ $0.identifier == selectedMessage.identifier }).first!
            sliceMessage.translation = translation
            sliceMessage.languagePair = translation.languagePair
            
            ConversationArchiver.clearArchive()
            ConversationArchiver.addToArchive(self.GLOBAL_CONVERSATION)
            
            defer {
                self.delegate.messagesCollectionView.reloadItems(at: [IndexPath(row: 0, section: selectedSection)])
                self.selectedCell = nil
                self.isRetranslating = false
            }
            
            guard var conversations = self.CURRENT_USER.openConversations else {
                Logger.log(Exception("Couldn't retrieve conversations from RuntimeStorage.",
                                     metadata: [#file, #function, #line]))
                return
            }
            
            conversations = conversations.filter({ $0.identifier.key != self.GLOBAL_CONVERSATION.identifier.key })
            conversations.append(self.GLOBAL_CONVERSATION)
            self.CURRENT_USER.openConversations = conversations
            
            //            let updatedMessageSlice = RuntimeStorage.globalConversation!.get(.last,
            //                                                                             messages: 10,
            //                                                                             offset: RuntimeStorage.messageOffset!)
            
            //            RuntimeStorage.store(updatedMessageSlice, as: .currentMessageSlice)
            //            RuntimeStorage.store(true, as: .shouldReloadData)
        }
    }
    
    //==================================================//
    
    /* MARK: - Helper Methods */
    
    private func correctLanguagePair(for message: Message) -> Message {
        syncDependencies()
        
        var languagePair = message.translation.languagePair
        
        let sameInputOutput = languagePair.from == languagePair.to
        
        guard message.fromAccountIdentifier == CURRENT_USER_ID else {
            languagePair = sameInputOutput ? LanguagePair(from: languagePair.from,
                                                          to: CURRENT_USER.languageCode) : languagePair
            if languagePair.from == languagePair.to {
                languagePair = LanguagePair(from: CURRENT_USER.languageCode,
                                            to: OTHER_USER.languageCode)
            }
            
            message.translation.languagePair = languagePair
            return message
        }
        
        languagePair = sameInputOutput ? LanguagePair(from: CURRENT_USER.languageCode,
                                                      to: languagePair.to) : languagePair
        
        if languagePair.from == languagePair.to {
            languagePair = LanguagePair(from: CURRENT_USER.languageCode,
                                        to: CURRENT_USER.languageCode)
        }
        
        message.translation.languagePair = languagePair
        return message
    }
    
    private func logError(_ exception: Exception,
                          showAlert: Bool) {
        Logger.closeStream()
        Core.hud.hide()
        isRetranslating = false
        Logger.log(exception, with: showAlert ? .errorAlert : .none)
    }
    
    private func retryTranslation(_ translation: Translation,
                                  using: TranslationPlatform,
                                  completion: @escaping(_ returnedTranslation: Translation?,
                                                        _ exception: Exception?) -> Void) {
        TranslationArchiver.clearArchive()
        
        FirebaseTranslator.shared.translate(translation.input,
                                            with: translation.languagePair,
                                            using: using) { returnedTranslation, exception in
            guard let translation = returnedTranslation else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            guard translation.input.value() != translation.output else {
                completion(nil, Exception("Translation result is still the same.", metadata: [#file, #function, #line]))
                return
            }
            
            TranslationArchiver.addToArchive(translation)
            TranslationSerializer.uploadTranslation(translation)
            
            completion(translation, nil)
        }
    }
}

public enum RetranslationServiceError: Error {
    case failedToRetrieveDependencies
}
