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
    
    /* MARK: - Constructor Method */
    
    public init(conversation: Binding<Conversation>) {
        self.conversation = conversation
        
        if ChatServices.deliveryService == nil,
           let deliveryService = try? DeliveryService(delegate: self) {
            ChatServices.register(service: deliveryService)
        }
        
        RuntimeStorage.store(self, as: .coordinator)
    }
}

//==================================================//

/* MARK: - Protocol Conformances */

/**/

/* MARK: DeliveryDelegate */
extension ChatPageViewCoordinator: DeliveryDelegate {
    public func setConversation(_ conversation: Conversation) {
        var mutableConversation = conversation
        mutableConversation.messages = mutableConversation.sortedFilteredMessages()
        
        self.conversation = Binding(get: { mutableConversation },
                                    set: { mutableConversation = $0 })
        
        RuntimeStorage.store(self.conversation.wrappedValue, as: .globalConversation)
        RuntimeStorage.store(RuntimeStorage.globalConversation!.get(.last, messages: 10),
                             as: .currentMessageSlice)
    }
}

/* MARK: InputBarAccessoryViewDelegate */
extension ChatPageViewCoordinator: InputBarAccessoryViewDelegate {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public var shouldEnableSendButton: Bool {
        guard let messagesVC = RuntimeStorage.messagesVC else { return false }
        
        let conversationNotEmpty = conversation.wrappedValue.identifier.key != "EMPTY"
        let hasSelectedContactPair = messagesVC.recipientBar?.selectedContactPair != nil
        let selectedContactPairNotEmpty = !(messagesVC.recipientBar?.selectedContactPair?.isEmpty ?? false)
        let isTextSendButton = !messagesVC.messageInputBar.sendButton.isRecordButton
        let textFieldIsEmpty = messagesVC.messageInputBar.inputTextView.text.lowercasedTrimmingWhitespace == ""
        
        guard !RuntimeStorage.isSendingMessage! else { return false }
        
        if isTextSendButton {
            guard !textFieldIsEmpty else { return false }
            guard conversationNotEmpty || (hasSelectedContactPair && selectedContactPairNotEmpty) else { return false }
            return true
        } else {
            guard conversationNotEmpty || (hasSelectedContactPair && selectedContactPairNotEmpty) else { return false }
            return true
        }
    }
    
    //==================================================//
    
    /* MARK: - Overridden Methods */
    
    public func inputBar(_ inputBar: InputBarAccessoryView,
                         didPressSendButtonWith text: String) {
        guard Build.isOnline else {
            AKCore.presentOfflineAlert()
            return
        }
        
        guard !inputBar.sendButton.isRecordButton else {
            switch text {
            case "START_RECORDING":
                handleRecordButtonTapped(inputBar, command: .startRecording)
            case "STOP_RECORDING":
                handleRecordButtonTapped(inputBar, command: .stopRecording)
            case "CANCEL_RECORDING":
                handleRecordButtonTapped(inputBar, command: .cancelRecording)
            default:
                return
            }
            return
        }
        
        ChatServices.defaultChatUIService?.setUserCancellation(enabled: false)
        
        inputBar.inputTextView.text = ""
        inputBar.sendButton.startAnimating()
        inputBar.sendButton.isEnabled = false
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        RuntimeStorage.store(true, as: .isSendingMessage)
        
        ChatServices.defaultDeliveryService?.sendTextMessage(text: text, completion: { exception in
            RuntimeStorage.store(false, as: .isSendingMessage)
            
            guard let exception else { return }
            Logger.log(exception)
        })
    }
    
    public func inputBar(_ inputBar: InputBarAccessoryView,
                         textViewTextDidChangeTo text: String) {
        guard let currentUser = RuntimeStorage.currentUser else { return }
        
        let isTyping = text.lowercasedTrimmingWhitespace != ""
        if conversation.wrappedValue.identifier.key != "EMPTY" {
            currentUser.update(isTyping: isTyping,
                               inConversationWithID: conversation.identifier.wrappedValue!.key)
        }
        
        let lines = Int(inputBar.inputTextView.contentSize.height / inputBar.inputTextView.font.lineHeight)
        let currentText = inputBar.inputTextView.text!
        
        if (lines > 1 || currentText.contains("\n")) && currentText != "" {
            inputBar.rightStackView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 5.5, right: 5)
            inputBar.rightStackView.isLayoutMarginsRelativeArrangement = true
            
            inputBar.sendButton.setSize(CGSize(width: 30, height: 30), animated: false)
            inputBar.setStackViewItems([.fixedSpace(5),
                                        inputBar.sendButton],
                                       forStack: .right,
                                       animated: false)
            
            inputBar.rightStackView.alignment = .bottom
        } else {
            inputBar.rightStackView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            inputBar.rightStackView.isLayoutMarginsRelativeArrangement = true
            
            inputBar.sendButton.setSize(CGSize(width: 30, height: 30), animated: false)
            inputBar.setStackViewItems([inputBar.sendButton],
                                       forStack: .right,
                                       animated: false)
            
            inputBar.rightStackView.alignment = .center
        }
        
        defer { inputBar.sendButton.isEnabled = shouldEnableSendButton }
        
        if currentText != "" {
            ChatServices.defaultAudioMessageService?.removeGestureRecognizers()
        }
        
        if currentText != "" && inputBar.sendButton.isRecordButton {
            ChatServices.defaultChatUIService?.configureInputBar(forRecord: false)
        } else if currentText == "" && !inputBar.sendButton.isRecordButton {
            guard ChatServices.defaultChatUIService?.shouldShowRecordButton ?? true else {
                ChatServices.defaultChatUIService?.configureInputBar(forRecord: false)
                return
            }
            
            ChatServices.defaultChatUIService?.configureInputBar(forRecord: true)
            ChatServices.defaultAudioMessageService?.addGestureRecognizers()
        }
    }
    
    //==================================================//
    
    /* MARK: - Recording Methods */
    
    private enum RecordButtonCommand { case startRecording; case stopRecording; case cancelRecording }
    private func handleRecordButtonTapped(_ inputBar: InputBarAccessoryView,
                                          command: RecordButtonCommand) {
        switch command {
        case .startRecording:
            ChatServices.defaultMenuControllerService?.stopSpeakingIfNeeded()
            startRecording { exception in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                guard let exception else { return }
                Logger.log(exception)
            }
        case .stopRecording:
            stopRecording {
                inputBar.sendButton.startAnimating()
                ChatServices.defaultChatUIService?.setUserCancellation(enabled: false)
                inputBar.sendButton.isEnabled = false
            } completion: { inputFile, outputFile, translation, exception in
                guard let inputFile, let outputFile, let translation else {
                    self.handleStopRecordingException(exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                RuntimeStorage.store(true, as: .isSendingMessage)
                ChatServices.defaultDeliveryService?.sendAudioMessage(inputFile: inputFile,
                                                                      outputFile: outputFile,
                                                                      translation: translation,
                                                                      completion: { exception in
                    RuntimeStorage.store(false, as: .isSendingMessage)
                    
                    guard let exception else { return }
                    Logger.log(exception)
                })
            }
        case .cancelRecording:
            cancelRecording { exception in
                guard let exception else { return }
                Logger.log(exception, verbose: exception.isEqual(to: .noAudioRecorderToStop))
            }
        }
    }
    
    private func handleStopRecordingException(_ exception: Exception) {
        if exception.isEqual(toAny: [.noSpeechDetected, .retry]) {
            ChatServices.defaultAudioMessageService?.playVibration()
            Core.hud.flash(LocalizedString.noSpeechDetected, image: .micSlash)
        }
        
        if !exception.isEqual(to: .noAudioRecorderToStop) {
            ChatServices.defaultChatUIService?.setUserCancellation(enabled: true)
            guard let inputBar = RuntimeStorage.messagesVC?.messageInputBar else { return }
            inputBar.sendButton.stopAnimating()
            Core.gcd.after(seconds: 2) { inputBar.sendButton.isEnabled = self.shouldEnableSendButton }
        }
        
        let filterParams: [JRException] = [.cannotOpenFile, .noAudioRecorderToStop, .noSpeechDetected, .retry]
        guard !exception.isEqual(toAny: filterParams) else {
            Logger.log(exception, verbose: exception.isEqual(to: .noAudioRecorderToStop))
            return
        }
        
        Core.gcd.after(seconds: 2) { Logger.log(exception, with: .errorAlert) }
    }
    
    private func startRecording(completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        ChatServices.defaultAudioMessageService?.removeRecordingUI { exception in
            guard let exception,
                  !exception.isEqual(to: .noAudioRecorderToStop) else {
                ChatServices.defaultAudioMessageService?.initiateRecording()
                
                completion(nil)
                return
            }
            
            completion(exception)
        }
    }
    
    private func stopRecording(progressHandler: @escaping() -> Void?,
                               completion: @escaping(_ inputFile: AudioFile?,
                                                     _ outputFile: AudioFile?,
                                                     _ translation: Translator.Translation?,
                                                     _ exception: Exception?) -> Void) {
        ChatServices.defaultAudioMessageService?.finishRecording {
            progressHandler()
        } completion: { inputFile, outputFile, translation, exception in
            guard let inputFile, let outputFile, let translation else {
                completion(nil, nil, nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(inputFile, outputFile, translation, nil)
        }
    }
    
    private func cancelRecording(completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        ChatServices.defaultAudioMessageService?.playVibration()
        ChatServices.defaultAudioMessageService?.removeRecordingUI(completion: { exception in
            completion(exception)
        })
    }
}

/* MARK: MessageCellDelegate */
extension ChatPageViewCoordinator: MessageCellDelegate {
    public func didTapPlayButton(in cell: AudioMessageCell) {
        AudioPlaybackController.startPlayback(for: cell)
    }
}

/* MARK: MessagesDataSource */
extension ChatPageViewCoordinator: MessagesDataSource {
    public func cellBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        guard let currentUser = RuntimeStorage.currentUser,
              let messageSlice = RuntimeStorage.currentMessageSlice,
              messageSlice.count > indexPath.section else { return nil }
        
        let currentMessage = messageSlice[indexPath.section]
        let translation = currentMessage.translation!
        let lastMessageIndex = messageSlice.count - 1
        
        // #warning("DANGEROUS TO BE HANDLING AUDIO COMPONENT HERE.")
        if currentMessage.audioComponent == nil,
           translation.input.value() == translation.output,
           RecognitionService.shouldMarkUntranslated(translation.output,
                                                     for: translation.languagePair) {
            let retryString = LocalizedString.holdToRetry
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12),
                                                             .foregroundColor: UIColor.gray]
            
            return retryString.attributed(mainAttributes: attributes,
                                          alternateAttributes: attributes,
                                          alternateAttributeRange: [retryString])
        } else if indexPath.section == lastMessageIndex &&
                    messageSlice[lastMessageIndex].fromAccountIdentifier == currentUser.identifier &&
                    messageSlice[lastMessageIndex].identifier != "NEW" {
            let boldAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12),
                                                                 .foregroundColor: UIColor.gray]
            
            guard let readDate = messageSlice[lastMessageIndex].readDate else {
                return NSAttributedString(string: LocalizedString.delivered, attributes: boldAttributes)
            }
            
            let readString = "\(LocalizedString.read) \(readDate.formattedString())"
            return readString.attributed(mainAttributes: [.font: UIFont.systemFont(ofSize: 12),
                                                          .foregroundColor: UIColor.lightGray],
                                         alternateAttributes: boldAttributes,
                                         alternateAttributeRange: [LocalizedString.read])
        }
        
        return nil
    }
    
    public func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        guard let messages = RuntimeStorage.currentMessageSlice else { return nil }
        return messages[indexPath.section].sentDate.separatorDateString()
    }
    
    public func configureAudioCell(_ cell: AudioMessageCell, message: MessageType) {
        guard let message = message as? Message else { return }
        cell.playButton.isEnabled = message.identifier != "NEW"
    }
    
    public func currentSender() -> SenderType {
        return Sender(senderId: RuntimeStorage.currentUserID ?? "", displayName: "??")
    }
    
    public func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let dateString = Core.secondaryDateFormatter!.string(from: message.sentDate)
        return NSAttributedString(string: dateString,
                                  attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2)])
    }
    
    public func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        guard let currentUser = RuntimeStorage.currentUser,
              let currentUserID = RuntimeStorage.currentUserID,
              let messages = RuntimeStorage.currentMessageSlice else { return Message.empty() }
        
        guard !messages.isEmpty else { return Message.empty() }
        guard indexPath.section < messages.count else { return messages[messages.count - 1] }
        
        let message = messages[indexPath.section]
        if indexPath.section == messages.count - 1 &&
            message.fromAccountIdentifier != currentUserID &&
            message.readDate == nil {
            message.updateReadDate()
            for (index, message) in messages[0...indexPath.section].enumerated() {
                print("updating read date for message #\(index + 1) before current")
                message.updateReadDate()
            }
            
#if !EXTENSION
            UIApplication.shared.applicationIconBadgeNumber = currentUser.badgeNumber
#endif
            RuntimeStorage.store(true, as: .shouldUpdateReadState)
        }
        
        return message
    }
    
    public func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        guard let messages = RuntimeStorage.currentMessageSlice else { return 0 }
        return messages.count
    }
}

/* MARK: MessagesDisplayDelegate */
extension ChatPageViewCoordinator: MessagesDisplayDelegate {
    public func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        guard let currentUserID = RuntimeStorage.currentUserID else { return .systemBlue }
        
        var color = UIColor(hex: 0xE5E5EA)
        if UITraitCollection.current.userInterfaceStyle == .dark {
            color = UIColor(hex: 0x27252A)
        }
        
        let index = indexPath.section
        guard let messages = RuntimeStorage.currentMessageSlice,
              messages[index].translation.input.value() == messages[index].translation.output,
              messages[index].audioComponent == nil, // #warning("DANGEROUS TO BE HANDLING AUDIO COMPONENT HERE.")
              message.sender.senderId == currentUserID,
              RecognitionService.shouldMarkUntranslated(messages[index].translation.output,
                                                        for: messages[index].translation.languagePair) else {
            return message.sender.senderId == currentUserID ? .systemBlue : color
        }
        
        return UIColor(hex: 0x65C466)
    }
    
    public func configureAvatarView(_ avatarView: AvatarView,
                                    for message: MessageType,
                                    at indexPath: IndexPath,
                                    in messagesCollectionView: MessagesCollectionView) {
        guard let currentUserID = RuntimeStorage.currentUserID,
              let otherUser = conversation.wrappedValue.otherUser,
              message.sender.senderId != currentUserID else { return }
        
        func showGenericAvatar() {
            avatarView.image = UIImage(named: "Contact.png")
            avatarView.tintColor = .gray
            avatarView.backgroundColor = .clear
        }
        
        if let contactThumbnail = ContactService.fetchContactThumbnail(forUser: otherUser),
           contactThumbnail != UIImage() {
            avatarView.image = contactThumbnail
        } else if let name = ContactService.fetchContactName(forUser: otherUser),
                  name != ("", ""),
                  let firstInitial = name.givenName.first?.uppercased(),
                  let lastInitial = name.familyName.first?.uppercased() {
            avatarView.set(avatar: Avatar(image: nil, initials: "\(firstInitial)\(lastInitial)"))
        } else {
            showGenericAvatar()
        }
    }
    
    public func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        guard let currentUserID = RuntimeStorage.currentUserID else { return .none }
        return message.sender.senderId == currentUserID ? .bubbleTail(.bottomRight, .curved) : .bubbleTail(.bottomLeft, .curved)
    }
}

/* MARK: MessagesLayoutDelegate */
extension ChatPageViewCoordinator: MessagesLayoutDelegate {
    public func cellBottomLabelHeight(for message: MessageType,
                                      at indexPath: IndexPath,
                                      in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        guard let currentUser = RuntimeStorage.currentUser,
              let messageSlice = RuntimeStorage.currentMessageSlice,
              messageSlice.count > indexPath.section else { return 0 }
        
        let lastMessageIndex = messageSlice.count - 1
        let messageTranslation: Translator.Translation = messageSlice[indexPath.section].translation
        
        // #warning("DANGEROUS TO BE HANDLING AUDIO COMPONENT HERE.")
        if (messageTranslation.input.value() == messageTranslation.output &&
            RecognitionService.shouldMarkUntranslated(messageTranslation.output,
                                                      for: messageTranslation.languagePair) &&
            messageSlice[indexPath.section].audioComponent == nil) ||
            (indexPath.section == lastMessageIndex &&
             messageSlice[lastMessageIndex].fromAccountIdentifier == currentUser.identifier) {
            return 20.0
        } else if indexPath.section == lastMessageIndex {
            return 5
        }
        
        return 0
    }
    
    public func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath,
                                   in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        let index = indexPath.section
        guard index != 0 else { return 15 }
        
        guard let messages = RuntimeStorage.currentMessageSlice,
              messages.count > index,
              (index - 1) > -1,
              messages[index].sentDate.seconds(from: messages[index - 1].sentDate) > 5400 else { return 0 }
        
        return 25
    }
    
    public func messageTopLabelHeight(for message: MessageType,
                                      at indexPath: IndexPath,
                                      in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return indexPath.section == 0 ? 10 : 0
    }
}

/* MARK: MessageType */
extension Message: MessageType {
    public struct Sender: SenderType {
        public let senderId: String
        public let displayName: String
    }
    
    public var kind: MessageKind {
        let isFromCurrentUser = fromAccountIdentifier == RuntimeStorage.currentUserID
        let textMessageKind: MessageKind = .text(!isFromCurrentUser ? translation.output : translation.input.value())
        
        guard hasAudioComponent,
              let audioComponent,
              let fileToUse = isFromCurrentUser ? audioComponent.original : audioComponent.translated else {
            return textMessageKind
        }
        
        return .audio(fileToUse)
    }
    
    public var messageId: String { identifier }
    public var sender: SenderType { Sender(senderId: fromAccountIdentifier, displayName: "??") }
}
