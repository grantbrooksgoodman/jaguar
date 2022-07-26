//
//  ChatPageViewCoordinator.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import SwiftUI

/* Third-party Frameworks */
import InputBarAccessoryView
import MessageKit

public final class ChatPageViewCoordinator {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    public var conversation: Binding<Conversation>
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(conversation: Binding<Conversation>) {
        self.conversation = conversation
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: InputBarAccessoryViewDelegate */
extension ChatPageViewCoordinator: InputBarAccessoryViewDelegate {
    public func inputBar(_ inputBar: InputBarAccessoryView,
                         didPressSendButtonWith text: String) {
        let wrappedConversation = conversation.wrappedValue
        let otherUser = wrappedConversation.otherUser!
        
        inputBar.sendButton.startAnimating()
        inputBar.inputTextView.text = ""
        inputBar.inputTextView.placeholder = "Sending..."
        inputBar.inputTextView.tintColor = .clear
        
        let languagePair = LanguagePair(from: currentUser!.languageCode,
                                        to: otherUser.languageCode)
        
        //        let message = Message(identifier: "!",
        //                              fromAccountIdentifier: currentUser!.identifier,
        //                              languagePair: languagePair,
        //                              translation: Translation(input: TranslationInput(text),
        //                                                       output: text,
        //                                                       languagePair: languagePair),
        //                              readDate: nil,
        //                              sentDate: Date())
        //
        //        self.conversation.messages.wrappedValue?.append(message)
        //        shouldReloadData = true
        
        TranslatorService.main.translate(TranslationInput(text),
                                         with: languagePair,
                                         using: .google) { (returnedTranslation, errorDescriptor) in
            inputBar.sendButton.stopAnimating()
            inputBar.inputTextView.placeholder = " New Message"
            inputBar.inputTextView.tintColor = .systemBlue
            
            guard let translation = returnedTranslation else {
                Logger.log(errorDescriptor ?? "An unknown error occurred.",
                           with: .normalAlert,
                           metadata: [#file, #function, #line])
                return
            }
            
            MessageSerializer.shared.createMessage(fromAccountWithIdentifier: currentUserID,
                                                   inConversationWithIdentifier: wrappedConversation.identifier,
                                                   translation: translation/*,
                                                   position: wrappedConversation.messages.count*/) { (returnedMessage, errorDescriptor) in
                guard let message = returnedMessage else {
                    Logger.log(errorDescriptor ?? "An unknown error occurred.",
                               with: .normalAlert,
                               metadata: [#file, #function, #line])
                    return
                }
                
                wrappedConversation.messages.append(message)
                wrappedConversation.messages = wrappedConversation.sortedFilteredMessages()
                topLevelMessages = wrappedConversation.messages
                shouldReloadData = true
            }
                                         }
    }
    
    public func inputBar(_ inputBar: InputBarAccessoryView,
                         textViewTextDidChangeTo text: String) {
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
}

/* MARK: MessageType */
extension Message: MessageType {
    public struct Sender: SenderType {
        public let senderId: String
        public let displayName: String
    }
    
    public var kind: MessageKind {
        return .text(fromAccountIdentifier != currentUserID ? translation.output : translation.input.value())
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
        return Sender(senderId: currentUserID, displayName: "??")
    }
    
    public func cellBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let messageArray = conversation.wrappedValue.messages!
        
        let lastMessageIndex = messageArray.count - 1
        
        if indexPath.section == lastMessageIndex && messageArray[lastMessageIndex].fromAccountIdentifier == currentUser!.identifier {
            let boldAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: UIColor.gray]
            
            if let readDate = messageArray[lastMessageIndex].readDate {
                let readString = "Read \(readDate.formattedString())"
                let attributedReadString = NSMutableAttributedString(string: readString)
                
                let readLength = "Read".count
                
                let regularAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.lightGray]
                
                attributedReadString.addAttributes(boldAttributes, range: NSRange(location: 0, length: readLength))
                
                attributedReadString.addAttributes(regularAttributes, range: NSRange(location: readLength, length: attributedReadString.length - readLength))
                
                return attributedReadString
            } else {
                return NSAttributedString(string: "Delivered", attributes: boldAttributes)
            }
        }
        
        return nil
    }
    
    public func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        return conversation.wrappedValue.messages[indexPath.section].sentDate.separatorDateString()
    }
    
    public func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return conversation.messages.wrappedValue.count
    }
    
    public func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let dateString = secondaryDateFormatter.string(from: message.sentDate)
        
        return NSAttributedString(string: dateString, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2)])
    }
    
    public func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return conversation.messages.wrappedValue[indexPath.section]
    }
}

/* MARK: MessagesLayoutDelegate */
extension ChatPageViewCoordinator: MessagesDisplayDelegate {
    public func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return message.sender.senderId == currentUserID ? .systemBlue : UIColor(hex: 0xE5E5EA)
    }
    
    public func configureAvatarView(_ avatarView: AvatarView,
                                    for message: MessageType,
                                    at indexPath: IndexPath,
                                    in messagesCollectionView: MessagesCollectionView) {
        
        if message.sender.senderId != currentUserID {
            if let contactThumbnail = ContactsServer.fetchContactThumbnail(forNumber: conversation.wrappedValue.otherUser!.phoneNumber.digits) {
                avatarView.image = contactThumbnail
            } else if let name = ContactsServer.fetchContactName(forNumber: conversation.wrappedValue.otherUser!.phoneNumber.digits) {
                
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
        return message.sender.senderId == currentUserID ? .bubbleTail(.bottomRight, .curved) : .bubbleTail(.bottomLeft, .curved)
    }
}

/* MARK: MessagesLayoutDelegate */
extension ChatPageViewCoordinator: MessagesLayoutDelegate {
    public func cellBottomLabelHeight(for message: MessageType,
                                      at indexPath: IndexPath,
                                      in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        let lastMessageIndex = conversation.wrappedValue.messages.count - 1
        
        if indexPath.section == lastMessageIndex && conversation.wrappedValue.messages[lastMessageIndex].fromAccountIdentifier == currentUser!.identifier {
            return 20.0
        } else if indexPath.section == lastMessageIndex {
            return 5
        }
        
        return 0
    }
    
    public func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath,
                                   in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        if (indexPath.section - 1) > -1 {
            if conversation.wrappedValue.messages[indexPath.section].sentDate.amountOfSeconds(from: conversation.wrappedValue.messages[indexPath.section - 1].sentDate) > 5400 {
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
