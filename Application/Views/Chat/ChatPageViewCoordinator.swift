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
    
    /* MARK: - Constructor */
    
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
        mutableConversation.messages = mutableConversation.messages.filteredAndSorted
        
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
            AKCore.shared.connectionAlertDelegate()?.presentConnectionAlert()
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
        
        // #warning("Should handle this more cleverly. What if someone actually wanted to send this?")
        guard text != "START_RECORDING",
              text != "STOP_RECORDING",
              text != "CANCEL_RECORDING",
              text.lowercasedTrimmingWhitespace != "" else { return }
        
        showSendingUI(inputBar)
        ChatServices.defaultChatUIService?.setUserCancellation(enabled: false)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        RuntimeStorage.store(true, as: .isSendingMessage)
        
        ChatServices.defaultDeliveryService?.sendTextMessage(text: text, completion: { exception in
            RuntimeStorage.store(false, as: .isSendingMessage)
            ChatServices.defaultChatUIService?.showMenuForFirstMessageIfNeeded()
            
            inputBar.inputTextView.tintColor = .primaryAccentColor
            
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
        RuntimeStorage.store(true, as: .isSendingMessage)
        
        switch command {
        case .startRecording:
            AudioPlaybackController.stopPlayback()
            ChatServices.defaultMenuControllerService?.hideMenuIfNeeded()
            ChatServices.defaultMenuControllerService?.stopSpeakingIfNeeded()
            
            startRecording { exception in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                guard let exception else { return }
                Logger.log(exception)
                RuntimeStorage.store(false, as: .isSendingMessage)
            }
        case .stopRecording:
            stopRecording {
                self.showSendingUI(inputBar)
                ChatServices.defaultChatUIService?.setUserCancellation(enabled: false)
                inputBar.sendButton.isEnabled = false
            } completion: { inputFile, outputFile, translation, exception in
                guard let inputFile, let outputFile, let translation else {
                    self.handleStopRecordingException(exception ?? Exception(metadata: [#file, #function, #line]))
                    guard !inputBar.sendButton.isAnimating else { return }
                    RuntimeStorage.store(false, as: .isSendingMessage)
                    return
                }
                
                ChatServices.defaultDeliveryService?.sendAudioMessage(inputFile: inputFile,
                                                                      outputFile: outputFile,
                                                                      translation: translation,
                                                                      completion: { exception in
                    RuntimeStorage.store(false, as: .isSendingMessage)
                    ChatServices.defaultChatUIService?.showMenuForFirstMessageIfNeeded()
                    
                    inputBar.inputTextView.tintColor = .primaryAccentColor
                    
                    guard let exception else { return }
                    Logger.log(exception)
                })
            }
        case .cancelRecording:
            cancelRecording { exception in
                RuntimeStorage.store(false, as: .isSendingMessage)
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
    
    //==================================================//
    
    /* MARK: - Helper Methods */
    
    private func showSendingUI(_ inputBar: InputBarAccessoryView) {
        inputBar.inputTextView.text = ""
        inputBar.inputTextView.tintColor = .clear
        inputBar.sendButton.startAnimating()
        inputBar.sendButton.isEnabled = false
    }
}

/* MARK: MessageCellDelegate */
extension ChatPageViewCoordinator: MessageCellDelegate {
    public func didSelectDate(_ date: Date) {
        let interval = date.timeIntervalSinceReferenceDate
        guard let url = URL(string: "calshow:\(interval)") else { return }
        Core.open(url)
    }
    
    public func didSelectPhoneNumber(_ phoneNumber: String) {
        guard let url = URL(string: "tel://\(phoneNumber.digits)") else { return }
        Core.open(url)
    }
    
    public func didSelectURL(_ url: URL) {
        Core.open(url)
    }
    
    public func didTapPlayButton(in cell: AudioMessageCell) {
        AudioPlaybackController.startPlayback(for: cell)
    }
}

/* MARK: MessagesDataSource */
extension ChatPageViewCoordinator: MessagesDataSource {
    public func audioTintColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        guard let message = message as? Message,
              message.fromAccountIdentifier == RuntimeStorage.currentUser?.identifier else { return .primaryAccentColor }
        return .white
    }
    
    public func cellBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        guard let currentUser = RuntimeStorage.currentUser,
              let otherUser = conversation.wrappedValue.otherUser,
              let messageSlice = RuntimeStorage.currentMessageSlice,
              messageSlice.count > indexPath.section else { return nil }
        
        let currentMessage = messageSlice[indexPath.section]
        let translation = currentMessage.translation!
        let lastMessageIndex = messageSlice.count - 1
        
        // #warning("DANGEROUS TO BE HANDLING AUDIO COMPONENT HERE.")
        if currentMessage.audioComponent == nil,
           translation.input.value() == translation.output,
           currentUser.languageCode != otherUser.languageCode,
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
        
        guard message.fromAccountIdentifier != RuntimeStorage.currentUser?.identifier else {
            guard ThemeService.currentTheme == AppThemes.default else { return }
            cell.progressView.trackTintColor = message.backgroundColor.darker(by: 6)?.withAlphaComponent(0.8)
            return
        }
        
        cell.playButton.tintColor = .primaryAccentColor
        cell.progressView.progressTintColor = .primaryAccentColor
        cell.progressView.trackTintColor = nil
        cell.durationLabel.textColor = .primaryAccentColor
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
        guard let messages = RuntimeStorage.currentMessageSlice else { return .senderMessageBubbleColor }
        let currentMessage = messages[indexPath.section]
        return currentMessage.backgroundColor
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
    
    public func detectorAttributes(for detector: DetectorType, and message: MessageType, at indexPath: IndexPath) -> [NSAttributedString.Key : Any] {
        let isFromCurrentUser = message.sender.senderId == RuntimeStorage.currentUserID
        let isDarkMode = ColorProvider.shared.interfaceStyle == .dark || ThemeService.currentTheme.style == .dark
        let colorToUse = isFromCurrentUser ? UIColor.white : (isDarkMode ? .white : .black)
        var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: colorToUse,
                                                         .underlineStyle: NSUnderlineStyle.single.rawValue]
        
        guard let cell = RuntimeStorage.messagesVC?.messagesCollectionView.cellForItem(at: indexPath) as? TextMessageCell else { return attributes }
        attributes[.font] = cell.messageLabel.font
        return attributes
    }
    
    public func enabledDetectors(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> [DetectorType] {
        return [.date, .phoneNumber, .url]
    }
    
    public func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        guard ThemeService.currentTheme != AppThemes.default else {
            guard let currentUserID = RuntimeStorage.currentUserID else { return .none }
            return message.sender.senderId == currentUserID ? .bubbleTail(.bottomRight, .curved) : .bubbleTail(.bottomLeft, .curved)
        }
        
        return .custom({ $0.layer.cornerRadius = 10 })
    }
}

/* MARK: MessagesLayoutDelegate */
extension ChatPageViewCoordinator: MessagesLayoutDelegate {
    public func cellBottomLabelHeight(for message: MessageType,
                                      at indexPath: IndexPath,
                                      in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        guard let currentUser = RuntimeStorage.currentUser,
              let otherUser = conversation.wrappedValue.otherUser,
              let messageSlice = RuntimeStorage.currentMessageSlice,
              messageSlice.count > indexPath.section else { return 0 }
        
        let lastMessageIndex = messageSlice.count - 1
        let messageTranslation: Translator.Translation = messageSlice[indexPath.section].translation
        
        // #warning("DANGEROUS TO BE HANDLING AUDIO COMPONENT HERE.")
        if (messageTranslation.input.value() == messageTranslation.output &&
            currentUser.languageCode != otherUser.languageCode &&
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
