//
//  ChatPageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 06/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import Firebase
import FirebaseDatabase
import InputBarAccessoryView
import MessageKit

//==================================================//

/* MARK: - Top-level Variable Declarations */

//Boolean Declarations
public var shouldReloadData = false
public var typingIndicator: Bool?

//Other Declarations
public var fullMessages: [Message]!
public var topLevelMessages: [Message]!

//==================================================//

public struct ChatPageView: UIViewControllerRepresentable {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    @State var initialized = false
    @Binding var conversation: Conversation
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public func makeCoordinator() -> ChatPageViewCoordinator {
        return ChatPageViewCoordinator(conversation: $conversation)
    }
    
    public func makeUIViewController(context: Context) -> MessagesViewController {
        let messagesVC = ChatPageViewController()
        
        messagesVC.messagesCollectionView.messagesDisplayDelegate = context.coordinator
        messagesVC.messagesCollectionView.messagesLayoutDelegate = context.coordinator
        messagesVC.messagesCollectionView.messagesDataSource = context.coordinator
        //        messagesVC.messagesCollectionView.prefetchDataSource = messagesVC
        messagesVC.messageInputBar.delegate = context.coordinator
        messagesVC.scrollsToLastItemOnKeyboardBeginsEditing = true // default false
        //messagesVC.maintainPositionOnInputBarHeightChanged = true // default false
        messagesVC.showMessageTimestampOnSwipeLeft = true // default false
        
        conversation.messages = conversation.sortedFilteredMessages()
        fullMessages = conversation.messages
        topLevelMessages = conversation.messages
        
        let inputBar = messagesVC.messageInputBar
        
        inputBar.contentView.clipsToBounds = true
        inputBar.contentView.layer.cornerRadius = 15
        inputBar.contentView.layer.borderWidth = 0.5
        inputBar.contentView.layer.borderColor = UIColor.systemGray.cgColor
        
        inputBar.sendButton.setImage(UIImage(named: "Send"), for: .normal)
        inputBar.sendButton.setImage(UIImage(named: "Send (Highlighted)"), for: .highlighted)
        
        inputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 5,
                                                                 left: 5,
                                                                 bottom: 5,
                                                                 right: 0)
        let localizedString = Localizer.preLocalizedString(for: .newMessage)
        
        inputBar.inputTextView.placeholder = " \(localizedString ?? " New Message")"
        
        setUpNewMessageObserver()
        setUpReadDateObserver()
        setUpTypingIndicatorObserver()
        
        currentFile = #file
        
        return messagesVC
    }
    
    public func updateUIViewController(_ uiViewController: MessagesViewController, context: Context) {
        uiViewController.messagesCollectionView.reloadData()
        scrollToBottom(uiViewController)
    }
    
    //==================================================//
    
    /* MARK: - Observer Functions */
    
    private func setUpNewMessageObserver() {
        Database.database().reference().child("allConversations/\(conversation.identifier!)/messages").observe(.childAdded) { (returnedSnapshot) in
            
            guard let identifier = returnedSnapshot.value as? String,
                  !conversation.messages.contains(where: { $0.identifier == identifier }) else {
                return
            }
            
            MessageSerializer.shared.getMessage(withIdentifier: identifier) { (returnedMessage,
                                                                               errorDescriptor) in
                guard let message = returnedMessage else {
                    if let error = errorDescriptor,
                       error != "Null/first message processed." {
                        Logger.log(error,
                                   metadata: [#file, #function, #line])
                    }
                    
                    return
                }
                
                guard message.fromAccountIdentifier != currentUserID else {
                    return
                }
                
                print("Appending message with ID: \(message.identifier!)")
                conversation.messages.append(message)
                conversation.messages = conversation.sortedFilteredMessages()
                
                shouldReloadData = true
            }
        } withCancel: { (error) in
            Logger.log(error,
                       metadata: [#file, #function, #line])
        }
    }
    
    private func setUpReadDateObserver() {
        #warning("Such a broad observer isn't great for efficiency, but it may be the only way to do this with the current database scheme.")
        Database.database().reference().child("/allMessages").observe(.childChanged) { (returnedSnapshot) in
            guard let lastMessage = conversation.sortedFilteredMessages().last else {
                Logger.log("Couldn't get last message.",
                           metadata: [#file, #function, #line])
                return
            }
            
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  let data = snapshot as? [String: Any] else {
                Logger.log("Couldn't unwrap snapshot.",
                           metadata: [#file, #function, #line])
                return
            }
            
            guard returnedSnapshot.key == lastMessage.identifier else {
                return
            }
            
            guard let readDateString = data["readDate"] as? String,
                  let readDate = secondaryDateFormatter.date(from: readDateString) else {
                Logger.log("Couldn't deserialize «readDate».",
                           metadata: [#file, #function, #line])
                return
            }
            
            lastMessage.readDate = readDate
            shouldReloadData = true
        } withCancel: { (returnedError) in
            Logger.log(returnedError,
                       metadata: [#file, #function, #line])
        }
    }
    
    private func setUpTypingIndicatorObserver() {
        Database.database().reference().child("/allConversations/\(conversation.identifier!)/participants").observe(.childChanged) { (returnedSnapshot) in
            guard let updatedTyper = returnedSnapshot.value as? String,
                  updatedTyper.components(separatedBy: " | ")[0] != currentUserID else {
                return
            }
            
            typingIndicator = updatedTyper.components(separatedBy: " | ")[1] == "true"
        } withCancel: { (returnedError) in
            Logger.log(returnedError,
                       metadata: [#file, #function, #line])
        }
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    private func scrollToBottom(_ uiViewController: MessagesViewController) {
        DispatchQueue.main.async {
            // The initialized state variable allows us to start at the bottom with the initial messages without seeing the initial scroll flash by
            uiViewController.messagesCollectionView.scrollToLastItem(animated: self.initialized)
            self.initialized = true
        }
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Date */
extension Date {
    func amountOfSeconds(from date: Date) -> Int {
        return Calendar.current.dateComponents([.second], from: date, to: self).second ?? 0
    }
    
    func separatorDateString() -> NSAttributedString {
        let dateDifference = currentCalendar.startOfDay(for: Date()).distance(to: currentCalendar.startOfDay(for: self))
        
        let timeString = DateFormatter.localizedString(from: self,
                                                       dateStyle: .none,
                                                       timeStyle: .short)
        
        let overYearFormatter = DateFormatter()
        overYearFormatter.locale = Locale(identifier: languageCode)
        overYearFormatter.dateFormat = Locale.preferredLanguages[0] == "en-US" ? "MMM dd yyyy, " : "dd MMM yyyy, "
        
        
        let overYearString = overYearFormatter.string(from: self)
        
        let regularFormatter = DateFormatter()
        regularFormatter.locale = Locale(identifier: languageCode)
        regularFormatter.dateFormat = "yyyy-MM-dd"
        
        let underYearFormatter = DateFormatter()
        underYearFormatter.locale = Locale(identifier: languageCode)
        underYearFormatter.dateFormat = Locale.preferredLanguages[0] == "en-US" ? "E MMM d, " : "E d MMM, "
        
        let underYearString = underYearFormatter.string(from: self)
        
        if dateDifference == 0 {
            let separatorString = Localizer.preLocalizedString(for: .today) ?? "Today"
            
            return messagesAttributedString("\(separatorString) \(timeString)", separationIndex: separatorString.count)
        } else if dateDifference == -86400 {
            let separatorString = Localizer.preLocalizedString(for: .yesterday) ?? "Yesterday"
            
            return messagesAttributedString("\(separatorString) \(timeString)", separationIndex: separatorString.count)
        } else if dateDifference >= -604800 {
            let fromDateDay = regularFormatter.string(from: self).dayOfWeek()
            
            if fromDateDay != regularFormatter.string(from: Date()).dayOfWeek() {
                return messagesAttributedString("\(fromDateDay) \(timeString)", separationIndex: fromDateDay.count)
            } else {
                return messagesAttributedString(underYearString + timeString, separationIndex: underYearString.components(separatedBy: ",")[0].count + 1)
            }
        } else if dateDifference < -604800 && dateDifference > -31540000 {
            return messagesAttributedString(underYearString + timeString, separationIndex: underYearString.components(separatedBy: ",")[0].count + 1)
        }
        
        return messagesAttributedString(overYearString + timeString, separationIndex: overYearString.components(separatedBy: ",")[0].count + 1)
    }
}

/* MARK: UIFont */
extension UIFont {
    func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return UIFont(descriptor: descriptor!, size: 0) //size 0 means keep the size as it is
    }
    
    func bold() -> UIFont {
        return withTraits(traits: .traitBold)
    }
    
    func italic() -> UIFont {
        return withTraits(traits: .traitItalic)
    }
}
