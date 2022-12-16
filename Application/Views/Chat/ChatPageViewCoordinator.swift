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
    private var deliveryProgress: Float = 0.0 {
        didSet {
            guard deliveryProgress < 1 else {
                RuntimeStorage.messagesVC?.progressView?.setProgress(1, animated: true)
                
                UIView.animate(withDuration: 0.2,
                               delay: 0.5,
                               options: []) {
                    RuntimeStorage.messagesVC?.progressView?.alpha = 0
                } completion: { _ in
                    Core.gcd.after(seconds: 1) {
                        RuntimeStorage.messagesVC?.progressView?.progress = 0
                        self.deliveryProgress = 0
                    }
                }
                
                return
            }
            
            RuntimeStorage.messagesVC?.progressView?.alpha = 1
            RuntimeStorage.messagesVC?.progressView?.setProgress(self.deliveryProgress, animated: true)
        }
    }
    
    private var deliveryTimer: Timer?
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(conversation: Binding<Conversation>) {
        self.conversation = conversation
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func presentOfflineAlert() {
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
    }
    
    private func rollBackProgressForTimeout(_ inputBar: InputBarAccessoryView,
                                            text: String) {
        let wrappedConversation = conversation.wrappedValue
        
        toggleInputBar(inputBar, sending: false)
        
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
        
        guard var conversations = RuntimeStorage.currentUser?.openConversations else {
            Logger.log("Couldn't retrieve conversations from RuntimeStorage.",
                       with: .errorAlert,
                       metadata: [#file, #function, #line])
            return
        }
        
        conversations.removeLast()
        conversations.append(wrappedConversation)
        
        RuntimeStorage.currentUser!.openConversations = conversations
        RuntimeStorage.store(true, as: .shouldReloadData)
        RuntimeStorage.store(false, as: .isSendingMessage)
    }
    
    private func toggleInputBarForProgress(_ inputBar: InputBarAccessoryView,
                                           sending: Bool) {
        guard sending else {
            return
        }
        
        inputBar.inputTextView.text = ""
        inputBar.sendButton.isEnabled = false
    }
    
    private func toggleInputBar(_ inputBar: InputBarAccessoryView,
                                sending: Bool) {
        guard sending else {
            inputBar.sendButton.stopAnimating()
            
            let localizedString = Localizer.preLocalizedString(for: .newMessage)
            inputBar.inputTextView.placeholder = " \(localizedString ?? " New Message")"
            inputBar.inputTextView.tintColor = .systemBlue
            inputBar.inputTextView.isUserInteractionEnabled = true
            
            return
        }
        
        inputBar.sendButton.startAnimating()
        
        inputBar.inputTextView.text = ""
        inputBar.inputTextView.placeholder = Localizer.preLocalizedString(for: .sending) ?? "Sending..."
        inputBar.inputTextView.tintColor = .clear
        inputBar.inputTextView.isUserInteractionEnabled = false
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: InputBarAccessoryViewDelegate */
extension ChatPageViewCoordinator: InputBarAccessoryViewDelegate {
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public func inputBar(_ inputBar: InputBarAccessoryView, didSwipeTextViewWith gesture: UISwipeGestureRecognizer) {
        print("detected swipe")
    }
    
    public func inputBar(_ inputBar: InputBarAccessoryView,
                         didPressSendButtonWith text: String) {
        guard Build.isOnline else {
            self.presentOfflineAlert()
            return
        }
        
        RuntimeStorage.store(true, as: .isSendingMessage)
        
        let wrappedConversation = conversation.wrappedValue
        
        inputBar.inputTextView.text = ""
        inputBar.sendButton.isEnabled = false
        deliveryProgress += 0.1
        deliveryTimer = Timer.scheduledTimer(timeInterval: 0.01,
                                             target: self,
                                             selector: #selector(incrementProgress),
                                             userInfo: nil,
                                             repeats: true)
        
        Logger.openStream(metadata: [#file, #function, #line])
        
        guard wrappedConversation.identifier.key != "EMPTY" else {
            self.createConversationForNewMessage(inputBar: inputBar, text: text)
            return
        }
        
        finishSendingMessage(conversation: wrappedConversation,
                             inputBar: inputBar,
                             text: text)
    }
    
    @objc public func incrementProgress() {
        guard deliveryProgress + 0.001 < 1 else { return }
        deliveryProgress += 0.001
    }
    
    public func inputBar(_ inputBar: InputBarAccessoryView,
                         textViewTextDidChangeTo text: String) {
        let isTyping = text.lowercasedTrimmingWhitespace != ""
        if conversation.wrappedValue.identifier.key != "EMPTY" {
            RuntimeStorage.currentUser!.update(isTyping: isTyping,
                                               inConversationWithID: conversation.identifier.wrappedValue!.key)
        }
        
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
        
        inputBar.sendButton.isEnabled = (conversation.wrappedValue.identifier.key != "EMPTY" || RuntimeStorage.messagesVC?.recipientBar?.selectedContactPair != nil) && isTyping && !(RuntimeStorage.messagesVC?.recipientBar?.selectedContactPair?.isEmpty ?? false)
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
        
        guard var conversations = RuntimeStorage.currentUser?.openConversations else {
            Logger.log("Couldn't retrieve conversations from RuntimeStorage.",
                       with: .errorAlert,
                       metadata: [#file, #function, #line])
            return
        }
        
        conversations.append(wrappedConversation)
        RuntimeStorage.currentUser!.openConversations = conversations
        //        RuntimeStorage.store(conversations, as: .conversations)
        
        RuntimeStorage.store(true, as: .shouldReloadData)
    }
    
    private func createConversationForNewMessage(inputBar: InputBarAccessoryView,
                                                 text: String) {
        guard let user = ContactNavigationRouter.currentlySelectedUser else {
            Logger.log(Exception("No selected user!",
                                 metadata: [#file, #function, #line]))
            return
        }
        
        ConversationSerializer.shared.createConversation(between: [RuntimeStorage.currentUser!,
                                                                   user]) { conversation, exception in
            guard var createdConversation = conversation else {
                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            self.deliveryProgress += 0.2
            
            self.conversation = Binding(get: { createdConversation },
                                        set: { createdConversation = $0 })
            
            self.finishSendingMessage(conversation: self.conversation.wrappedValue,
                                      inputBar: inputBar,
                                      text: text)
            
            ContactNavigationRouter.currentlySelectedUser = nil
        }
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
    
    private func finishSendingMessage(conversation: Conversation,
                                      inputBar: InputBarAccessoryView,
                                      text: String) {
        appendMockMessage(text: text)
        
        let timeout = Timeout(alertingAfter: 20, metadata: [#file, #function, #line]) {
            self.rollBackProgressForTimeout(inputBar, text: text)
        }
        
        debugTranslate(text) { (returnedDebugTranslation,
                                exception) in
            guard let debugTranslation = returnedDebugTranslation else {
                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                           with: .errorAlert)
                RuntimeStorage.store(false, as: .isSendingMessage)
                return
            }
            
            self.deliveryProgress += 0.2
            
            self.translateMessage(debugTranslation.output,
                                  otherUser: conversation.otherUser!) { (returnedTranslation,
                                                                         exception) in
                self.deliveryProgress += 0.2
                
                guard let translation = returnedTranslation else {
                    Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                               with: .errorAlert)
                    RuntimeStorage.store(false, as: .isSendingMessage)
                    return
                }
                
                self.createMessage(withTranslation: translation) { (returnedMessage,
                                                                    exception) in
                    guard let message = returnedMessage else {
                        Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                                   with: .errorAlert)
                        RuntimeStorage.store(false, as: .isSendingMessage)
                        return
                    }
                    
                    self.deliveryProgress += 0.2
                    
                    self.updateConversationData(conversation,
                                                for: message,
                                                timeout: timeout)
                }
            }
        }
    }
    
    @objc private func toggleDoneButton() {
        if let messagesVC = RuntimeStorage.messagesVC {
            messagesVC.messageInputBar.inputTextView.resignFirstResponder()
        }
        
        StateProvider.shared.tappedDone = true
    }
    
    private func translateMessage(_ text: String,
                                  otherUser: User,
                                  completion: @escaping (_ returnedTranslation: Translator.Translation?,
                                                         _ exception: Exception?) -> Void) {
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
    
    private func updateConversationData(_ conversation: Conversation,
                                        for newMessage: Message,
                                        timeout: Timeout) {
        conversation.updateLastModified()
        
        conversation.messages.removeAll(where: { $0.identifier == "NEW" })
        conversation.messages.append(newMessage)
        
        conversation.messages = conversation.sortedFilteredMessages()
        
        deliveryProgress += 0.2
        deliveryTimer?.invalidate()
        deliveryTimer = nil
        
        conversation.updateHash { (exception) in
            timeout.cancel()
            
            if let error = exception {
                Logger.log(error,
                           with: .errorAlert)
            }
            
            RuntimeStorage.store(conversation, as: .globalConversation)
            
            guard var currentMessageSlice = RuntimeStorage.currentMessageSlice else {
                Logger.log("Couldn't retrieve current message slice from RuntimeStorage.",
                           with: .errorAlert,
                           metadata: [#file, #function, #line])
                RuntimeStorage.store(false, as: .isSendingMessage)
                return
            }
            
            currentMessageSlice.removeAll(where: { $0.identifier == "NEW" })
            currentMessageSlice.append(newMessage)
            RuntimeStorage.store(currentMessageSlice, as: .currentMessageSlice)
            
            print("Adding to archive \(conversation.identifier.key!) | \(conversation.identifier.hash!)")
            ConversationArchiver.addToArchive(conversation)
            
            guard var conversations = RuntimeStorage.currentUser?.openConversations else {
                Logger.log("Couldn't retrieve conversations from RuntimeStorage.",
                           with: .errorAlert,
                           metadata: [#file, #function, #line])
                RuntimeStorage.store(false, as: .isSendingMessage)
                return
            }
            
            conversations.removeLast()
            conversations.append(conversation)
            RuntimeStorage.currentUser!.openConversations = conversations
            
            RuntimeStorage.store(true, as: .shouldReloadData)
            RuntimeStorage.store(false, as: .isSendingMessage)
            
            Logger.closeStream()
            
            if self.deliveryProgress < 1 {
                self.deliveryProgress += 1 - self.deliveryProgress
            }
            
            // #warning("Do we want to couple these guard conditions?")
            guard let messagesVC = RuntimeStorage.messagesVC,
                  let pair = messagesVC.recipientBar?.selectedContactPair else { return }
            
            messagesVC.recipientBar?.removeFromSuperview()
            messagesVC.messagesCollectionView.contentInset.top = 0
            messagesVC.messagesCollectionView.isUserInteractionEnabled = true
            
            messagesVC.parent!.navigationItem.title = "\(pair.contact.firstName) \(pair.contact.lastName)"
            
            let doneButton = UIBarButtonItem(title: LocalizedString.done,
                                             style: .done,
                                             target: self,
                                             action: #selector(self.toggleDoneButton))
            messagesVC.parent!.navigationItem.rightBarButtonItems = [doneButton]
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
        let messages = RuntimeStorage.currentMessageSlice!
        
        if indexPath.section == messages.count - 1 &&
            messages[indexPath.section].fromAccountIdentifier != RuntimeStorage.currentUserID! &&
            messages[indexPath.section].readDate == nil {
            messages[indexPath.section].updateReadDate()
        }
        
        return messages[indexPath.section]
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
