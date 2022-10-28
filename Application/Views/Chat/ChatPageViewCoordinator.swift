//
//  ChatPageViewCoordinator.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import AlertKit
import InputBarAccessoryView
import MessageKit
import Translator

public final class ChatPageViewCoordinator {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public var conversation: Binding<Conversation>
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(conversation: Binding<Conversation>) {
        self.conversation = conversation
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func rollBackProgressForTimeout(_ inputBar: InputBarAccessoryView,
                                            text: String) {
        let wrappedConversation = conversation.wrappedValue
        
        inputBar.sendButton.stopAnimating()
        
        let localizedString = Localizer.preLocalizedString(for: .newMessage)
        inputBar.inputTextView.text = text
        inputBar.inputTextView.placeholder = " \(localizedString ?? " New Message")"
        inputBar.inputTextView.tintColor = .systemBlue
        inputBar.inputTextView.isUserInteractionEnabled = true
        
        wrappedConversation.messages.removeAll(where: { $0.identifier == "NEW" })
        wrappedConversation.messages = wrappedConversation.sortedFilteredMessages()
        
        RuntimeStorage.store(wrappedConversation, as: .globalConversation)
        
        guard var currentMessageSlice = RuntimeStorage.currentMessageSlice else {
            Logger.log("Couldn't retrieve current message slice from RuntimeStorage.",
                       with: .errorAlert,
                       metadata: [#file, #function, #line])
            return
        }
        
        currentMessageSlice.removeAll(where: { $0.identifier == "NEW" })
        RuntimeStorage.store(currentMessageSlice, as: .currentMessageSlice)
        
        ConversationArchiver.addToArchive(wrappedConversation)
        
        guard var conversations = RuntimeStorage.conversations else {
            Logger.log("Couldn't retrieve conversations from RuntimeStorage.",
                       with: .errorAlert,
                       metadata: [#file, #function, #line])
            return
        }
        
        conversations.removeLast()
        conversations.append(wrappedConversation)
        
        RuntimeStorage.store(conversations, as: .conversations)
        RuntimeStorage.store(true, as: .shouldReloadData)
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: InputBarAccessoryViewDelegate */
extension ChatPageViewCoordinator: InputBarAccessoryViewDelegate {
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public func inputBar(_ inputBar: InputBarAccessoryView,
                         didPressSendButtonWith text: String) {
        guard Build.isOnline else {
            AKCore.shared.setLanguageCode("en")
            
            let exception = Exception("The internet connection is offline.",
                                      isReportable: false,
                                      extraParams: ["IsConnected": Build.isOnline],
                                      metadata: [#file, #function, #line])
            
            AKErrorAlert(message: Localizer.preLocalizedString(for: .noInternetMessage,
                                                               language: RuntimeStorage.languageCode!) ?? "The internet connection appears to be offline.\nPlease connect to the internet and try again.",
                         error: exception.asAkError(),
                         cancelButtonTitle: "OK").present { _ in
                AKCore.shared.setLanguageCode(RuntimeStorage.languageCode!)
            }
            return
        }
        
        let wrappedConversation = conversation.wrappedValue
        
        inputBar.sendButton.startAnimating()
        
        inputBar.inputTextView.text = ""
        inputBar.inputTextView.placeholder = Localizer.preLocalizedString(for: .sending) ?? "Sending..."
        inputBar.inputTextView.tintColor = .clear
        inputBar.inputTextView.isUserInteractionEnabled = false
        
        Logger.openStream(metadata: [#file, #function, #line])
        appendMockMessage(text: text)
        
        let timeout = Timeout(alertingAfter: 10, metadata: [#file, #function, #line]) {
            self.rollBackProgressForTimeout(inputBar, text: text)
        }
        
        debugTranslate(text) { (returnedDebugTranslation,
                                exception) in
            guard let debugTranslation = returnedDebugTranslation else {
                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                           with: .errorAlert)
                return
            }
            
            self.translateMessage(debugTranslation.output) { (returnedTranslation,
                                                              exception) in
                inputBar.sendButton.stopAnimating()
                
                let localizedString = Localizer.preLocalizedString(for: .newMessage)
                inputBar.inputTextView.placeholder = " \(localizedString ?? " New Message")"
                inputBar.inputTextView.tintColor = .systemBlue
                inputBar.inputTextView.isUserInteractionEnabled = true
                
                guard let translation = returnedTranslation else {
                    Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                               with: .errorAlert)
                    return
                }
                
                self.createMessage(withTranslation: translation) { (returnedMessage,
                                                                    exception) in
                    guard let message = returnedMessage else {
                        Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                                   with: .errorAlert)
                        return
                    }
                    
                    wrappedConversation.updateLastModified()
                    
                    wrappedConversation.messages.removeAll(where: { $0.identifier == "NEW" })
                    wrappedConversation.messages.append(message)
                    
                    wrappedConversation.messages = wrappedConversation.sortedFilteredMessages()
                    
                    wrappedConversation.updateHash { (exception) in
                        timeout.cancel()
                        
                        if let error = exception {
                            Logger.log(error,
                                       with: .errorAlert)
                        }
                        
                        RuntimeStorage.store(wrappedConversation, as: .globalConversation)
                        
                        guard var currentMessageSlice = RuntimeStorage.currentMessageSlice else {
                            Logger.log("Couldn't retrieve current message slice from RuntimeStorage.",
                                       with: .errorAlert,
                                       metadata: [#file, #function, #line])
                            return
                        }
                        
                        currentMessageSlice.removeAll(where: { $0.identifier == "NEW" })
                        currentMessageSlice.append(message)
                        RuntimeStorage.store(currentMessageSlice, as: .currentMessageSlice)
                        
                        print("Adding to archive \(wrappedConversation.identifier.key!) | \(wrappedConversation.identifier.hash!)")
                        ConversationArchiver.addToArchive(wrappedConversation)
                        
                        guard var conversations = RuntimeStorage.conversations else {
                            Logger.log("Couldn't retrieve conversations from RuntimeStorage.",
                                       with: .errorAlert,
                                       metadata: [#file, #function, #line])
                            return
                        }
                        
                        conversations.removeLast()
                        conversations.append(wrappedConversation)
                        RuntimeStorage.store(conversations, as: .conversations)
                        
                        RuntimeStorage.store(true, as: .shouldReloadData)
                        
                        Logger.closeStream()
                    }
                }
            }
        }
    }
    
    public func inputBar(_ inputBar: InputBarAccessoryView,
                         textViewTextDidChangeTo text: String) {
        let isTyping = text.lowercasedTrimmingWhitespace != ""
        RuntimeStorage.currentUser!.update(isTyping: isTyping,
                                           inConversationWithID: conversation.identifier.wrappedValue!.key)
        
        let lines = Int(inputBar.inputTextView.contentSize.height / inputBar.inputTextView.font.lineHeight)
        let currentText = inputBar.inputTextView.text!
        
        if (lines > 1 || currentText.contains("\n")) && currentText != "" {
            inputBar.rightStackView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 3.5, right: 0)
            inputBar.rightStackView.isLayoutMarginsRelativeArrangement = true
            
            inputBar.rightStackView.alignment = .bottom
        } else {
            inputBar.rightStackView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            inputBar.rightStackView.isLayoutMarginsRelativeArrangement = true
            
            inputBar.rightStackView.alignment = .center
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func appendMockMessage(text: String) {
        let wrappedConversation = conversation.wrappedValue
        let otherUser = wrappedConversation.otherUser!
        
        let mockLanguagePair = Translator.LanguagePair(from: RuntimeStorage.currentUser!.languageCode,
                                                       to: otherUser.languageCode)
        
        let mockTranslation = Translator.Translation(input: TranslationInput(text),
                                                     output: "",
                                                     languagePair: mockLanguagePair)
        
        let mockMessage = Message(identifier: "NEW",
                                  fromAccountIdentifier: RuntimeStorage.currentUserID!,
                                  languagePair: mockLanguagePair,
                                  translation: mockTranslation,
                                  readDate: nil,
                                  sentDate: Date())
        
        wrappedConversation.messages.append(mockMessage)
        wrappedConversation.messages = wrappedConversation.sortedFilteredMessages()
        
        RuntimeStorage.store(wrappedConversation, as: .globalConversation)
        print("wrapped convo has \(wrappedConversation.messages.count)")
        print("global convo has \(RuntimeStorage.globalConversation!.messages.count)")
        
        guard var currentMessageSlice = RuntimeStorage.currentMessageSlice else {
            Logger.log("Couldn't retrieve current message slice from RuntimeStorage.",
                       with: .errorAlert,
                       metadata: [#file, #function, #line])
            return
        }
        
        currentMessageSlice.append(mockMessage)
        RuntimeStorage.store(currentMessageSlice, as: .currentMessageSlice)
        
        guard var conversations = RuntimeStorage.conversations else {
            Logger.log("Couldn't retrieve conversations from RuntimeStorage.",
                       with: .errorAlert,
                       metadata: [#file, #function, #line])
            return
        }
        
        conversations.append(wrappedConversation)
        RuntimeStorage.store(conversations, as: .conversations)
        
        RuntimeStorage.store(true, as: .shouldReloadData)
    }
    
    private func createMessage(withTranslation: Translator.Translation,
                               completion: @escaping (_ returnedMessage: Message?,
                                                      _ exception: Exception?) -> Void) {
        let wrappedConversation = conversation.wrappedValue
        
        MessageSerializer.shared.createMessage(fromAccountWithIdentifier: RuntimeStorage.currentUserID!,
                                               inConversationWithIdentifier: wrappedConversation.identifier!.key!,
                                               translation: withTranslation) { (returnedMessage,
                                                                                exception) in
            guard let message = returnedMessage else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(message, nil)
        }
    }
    
    private func debugTranslate(_ text: String,
                                completion: @escaping (_ returnedTranslation: Translator.Translation?,
                                                       _ exception: Exception?) -> Void) {
        let debugLanguagePair = Translator.LanguagePair(from: "en",
                                                        to: RuntimeStorage.currentUser!.languageCode)
        
        FirebaseTranslator.shared.translate(TranslationInput(text),
                                            with: debugLanguagePair) { (returnedTranslation, exception) in
            guard let translation = returnedTranslation else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(translation, nil)
        }
    }
    
    private func translateMessage(_ text: String,
                                  completion: @escaping (_ returnedTranslation: Translator.Translation?,
                                                         _ exception: Exception?) -> Void) {
        let wrappedConversation = conversation.wrappedValue
        let otherUser = wrappedConversation.otherUser!
        
        let languagePair = Translator.LanguagePair(from: RuntimeStorage.currentUser!.languageCode,
                                                   to: otherUser.languageCode)
        
        FirebaseTranslator.shared.translate(TranslationInput(text),
                                            with: languagePair,
                                            using: .google) { (returnedTranslation, exception) in
            guard let translation = returnedTranslation else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(translation, nil)
        }
    }
}

/* MARK: MessageType */
extension Message: MessageType {
    public struct Sender: SenderType {
        public let senderId: String
        public let displayName: String
    }
    
    public var kind: MessageKind {
        return .text(fromAccountIdentifier != RuntimeStorage.currentUserID! ? translation.output : translation.input.value())
    }
    
    public var messageId: String {
        return identifier
    }
    
    public var sender: SenderType {
        return Sender(senderId: fromAccountIdentifier, displayName: "??")
    }
}

/* MARK: MessagesDataSource */
extension ChatPageViewCoordinator: MessagesDataSource {
    public func currentSender() -> SenderType {
        return Sender(senderId: RuntimeStorage.currentUserID!, displayName: "??")
    }
    
    public func cellBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let messageArray = RuntimeStorage.currentMessageSlice!
        
        let lastMessageIndex = messageArray.count - 1
        
        if indexPath.section == lastMessageIndex &&
            messageArray[lastMessageIndex].fromAccountIdentifier == RuntimeStorage.currentUser!.identifier &&
            messageArray[lastMessageIndex].identifier != "NEW" {
            let boldAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: UIColor.gray]
            
            guard let readDate = messageArray[lastMessageIndex].readDate else {
                let deliveredString = Localizer.preLocalizedString(for: .delivered) ?? "Delivered"
                
                return NSAttributedString(string: deliveredString, attributes: boldAttributes)
            }
            
            let localizedReadString = Localizer.preLocalizedString(for: .read) ?? "Read"
            
            let readString = "\(localizedReadString) \(readDate.formattedString())"
            let attributedReadString = NSMutableAttributedString(string: readString)
            
            let readLength = localizedReadString.count
            
            let regularAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.lightGray]
            
            attributedReadString.addAttributes(boldAttributes, range: NSRange(location: 0, length: readLength))
            
            attributedReadString.addAttributes(regularAttributes, range: NSRange(location: readLength, length: attributedReadString.length - readLength))
            
            return attributedReadString
        }
        
        return nil
    }
    
    public func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        return RuntimeStorage.currentMessageSlice![indexPath.section].sentDate.separatorDateString()
    }
    
    public func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return RuntimeStorage.currentMessageSlice!.count
    }
    
    public func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let dateString = Core.secondaryDateFormatter!.string(from: message.sentDate)
        
        return NSAttributedString(string: dateString, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2)])
    }
    
    public func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        if indexPath.section == RuntimeStorage.currentMessageSlice!.count - 1 &&
            RuntimeStorage.currentMessageSlice![indexPath.section].fromAccountIdentifier != RuntimeStorage.currentUserID! &&
            RuntimeStorage.currentMessageSlice![indexPath.section].readDate == nil {
            RuntimeStorage.currentMessageSlice![indexPath.section].updateReadDate()
        }
        
        return RuntimeStorage.currentMessageSlice![indexPath.section]
    }
}

/* MARK: MessagesLayoutDelegate */
extension ChatPageViewCoordinator: MessagesDisplayDelegate {
    public func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        var color = UIColor(hex: 0xE5E5EA)
        
        if UITraitCollection.current.userInterfaceStyle == .dark {
            color = UIColor(hex: 0x27252A)
        }
        
        return message.sender.senderId == RuntimeStorage.currentUserID! ? .systemBlue : color
    }
    
    public func configureAvatarView(_ avatarView: AvatarView,
                                    for message: MessageType,
                                    at indexPath: IndexPath,
                                    in messagesCollectionView: MessagesCollectionView) {
        
        if message.sender.senderId != RuntimeStorage.currentUserID! {
            if let contactThumbnail = ContactService.fetchContactThumbnail(forNumber: conversation.wrappedValue.otherUser!.phoneNumber.digits),
               contactThumbnail != UIImage() {
                avatarView.image = contactThumbnail
            } else if let name = ContactService.fetchContactName(forNumber: conversation.wrappedValue.otherUser!.phoneNumber.digits),
                      name != ("", "") {
                
                avatarView.set(avatar: Avatar(image: nil,
                                              initials: "\(name.givenName.characterArray[0].uppercased())\(name.familyName.characterArray[0].uppercased())"))
            } else {
                avatarView.image = UIImage(named: "Contact.png")
                avatarView.tintColor = .gray
                avatarView.backgroundColor = .clear
            }
        }
    }
    
    public func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        return message.sender.senderId == RuntimeStorage.currentUserID! ? .bubbleTail(.bottomRight, .curved) : .bubbleTail(.bottomLeft, .curved)
    }
}

/* MARK: MessagesLayoutDelegate */
extension ChatPageViewCoordinator: MessagesLayoutDelegate {
    public func cellBottomLabelHeight(for message: MessageType,
                                      at indexPath: IndexPath,
                                      in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        let lastMessageIndex = RuntimeStorage.currentMessageSlice!.count - 1
        
        if indexPath.section == lastMessageIndex && RuntimeStorage.currentMessageSlice![lastMessageIndex].fromAccountIdentifier == RuntimeStorage.currentUser!.identifier {
            return 20.0
        } else if indexPath.section == lastMessageIndex {
            return 5
        }
        
        return 0
    }
    
    public func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath,
                                   in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        if (indexPath.section - 1) > -1 {
            if RuntimeStorage.currentMessageSlice![indexPath.section].sentDate.amountOfSeconds(from: RuntimeStorage.currentMessageSlice![indexPath.section - 1].sentDate) > 5400 {
                return 25
            }
        }
        
        if indexPath.section == 0 {
            return 15
        }
        
        return 0
    }
    
    public func messageTopLabelHeight(for message: MessageType,
                                      at indexPath: IndexPath,
                                      in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        if indexPath.section == 0 {
            return 10
        }
        
        return 0
    }
}
