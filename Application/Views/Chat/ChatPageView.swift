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

public struct ChatPageView: UIViewControllerRepresentable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
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
        messagesVC.messageInputBar.delegate = context.coordinator
        messagesVC.scrollsToLastItemOnKeyboardBeginsEditing = true // default false
        //messagesVC.maintainPositionOnInputBarHeightChanged = true // default false
        messagesVC.showMessageTimestampOnSwipeLeft = true // default false
        
        conversation.messages = conversation.sortedFilteredMessages()
        
        RuntimeStorage.store(conversation, as: .globalConversation)
        RuntimeStorage.store(RuntimeStorage.globalConversation!.get(.last, messages: 10), as: .currentMessageSlice)
        
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
        
        let randomSentence = SentenceGenerator.generateSentence(wordCount: Int().random(min: 3, max: 15))
        inputBar.inputTextView.text = randomSentence
        
        setUpNewMessageObserver()
        setUpReadDateObserver()
        setUpTypingIndicatorObserver()
        
        RuntimeStorage.store(#file, as: .currentFile)
        
        if let window = RuntimeStorage.topWindow!.subview(Core.ui.nameTag(for: "buildInfoOverlayWindow")) as? UIWindow {
            //            window.rootViewController = UIHostingController(rootView: BuildInfoOverlayView(yOffset: -20))
            window.isHidden = true
        }
        
        return messagesVC
    }
    
    public func updateUIViewController(_ uiViewController: MessagesViewController, context: Context) {
        uiViewController.messagesCollectionView.reloadData()
        scrollToBottom(uiViewController)
    }
    
    //==================================================//
    
    /* MARK: - Observer Functions */
    
    private func setUpNewMessageObserver() {
        Database.database().reference().child("allConversations/\(RuntimeStorage.globalConversation!.identifier!.key!)/messages").observe(.childAdded) { (returnedSnapshot) in
            
            guard let identifier = returnedSnapshot.value as? String,
                  !RuntimeStorage.globalConversation!.messages.contains(where: { $0.identifier == identifier }) else {
                return
            }
            
            MessageSerializer.shared.getMessage(withIdentifier: identifier) { (returnedMessage,
                                                                               errorDescriptor) in
                guard let message = returnedMessage else {
                    if let error = errorDescriptor,
                       error != "Null/first message processed." {
                        Logger.log(error,
                                   with: .errorAlert,
                                   metadata: [#file, #function, #line])
                    }
                    
                    return
                }
                
                guard message.fromAccountIdentifier != RuntimeStorage.currentUserID! else { return }
                
                print("Appending message with ID: \(message.identifier!)")
                conversation.messages.append(message)
                conversation.messages = conversation.sortedFilteredMessages()
                
                conversation.identifier.hash = conversation.hash
                
                RuntimeStorage.store(conversation, as: .globalConversation)
                RuntimeStorage.store(RuntimeStorage.globalConversation!.get(.last,
                                                                            messages: 10,
                                                                            offset: RuntimeStorage.messageOffset!),
                                     as: .currentMessageSlice)
                
                print("Adding to archive \(conversation.identifier.key!) | \(conversation.identifier.hash!)")
                ConversationArchiver.addToArchive(conversation)
                
                RuntimeStorage.store(true, as: .shouldReloadData)
            }
        } withCancel: { (error) in
            Logger.log(error,
                       with: .errorAlert,
                       metadata: [#file, #function, #line])
        }
    }
    
    private func setUpReadDateObserver() {
        #warning("Such a broad observer isn't great for efficiency, but it may be the only way to do this with the current database scheme.")
        Database.database().reference().child("/allMessages").observe(.childChanged) { returnedSnapshot, _ in
            guard let lastMessage = conversation.sortedFilteredMessages().last else {
                Logger.log("Couldn't get last message.",
                           with: .errorAlert,
                           metadata: [#file, #function, #line])
                return
            }
            
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  let data = snapshot as? [String: Any] else {
                Logger.log("Couldn't unwrap snapshot.",
                           with: .errorAlert,
                           metadata: [#file, #function, #line])
                return
            }
            
            guard returnedSnapshot.key == lastMessage.identifier else {
                return
            }
            
            guard let readDateString = data["readDate"] as? String,
                  let readDate = Core.secondaryDateFormatter!.date(from: readDateString) else {
                Logger.log("Couldn't deserialize «readDate».",
                           with: .errorAlert,
                           metadata: [#file, #function, #line])
                return
            }
            
            lastMessage.readDate = readDate
            RuntimeStorage.store(true, as: .shouldReloadData)
        } withCancel: { (returnedError) in
            Logger.log(returnedError,
                       with: .errorAlert,
                       metadata: [#file, #function, #line])
        }
    }
    
    private func setUpTypingIndicatorObserver() {
        Database.database().reference().child("/allConversations/\(RuntimeStorage.globalConversation!.identifier!.key!)/participants").observe(.childChanged) { (returnedSnapshot) in
            guard let updatedTyper = returnedSnapshot.value as? String,
                  updatedTyper.components(separatedBy: " | ")[0] != RuntimeStorage.currentUserID! else {
                return
            }
            
            RuntimeStorage.store(updatedTyper.components(separatedBy: " | ")[1] == "true",
                                 as: .typingIndicator)
        } withCancel: { (returnedError) in
            Logger.log(returnedError,
                       with: .errorAlert,
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
public extension Date {
    func amountOfSeconds(from date: Date) -> Int {
        return Calendar.current.dateComponents([.second], from: date, to: self).second ?? 0
    }
    
    func dayOfWeek() -> String? {
        switch Calendar.current.component(.weekday, from: self) {
        case 1:
            return Localizer.preLocalizedString(for: .sunday) ?? "Sunday"
        case 2:
            return Localizer.preLocalizedString(for: .monday) ?? "Monday"
        case 3:
            return Localizer.preLocalizedString(for: .tuesday) ?? "Tuesday"
        case 4:
            return Localizer.preLocalizedString(for: .wednesday) ?? "Wednesday"
        case 5:
            return Localizer.preLocalizedString(for: .thursday) ?? "Thursday"
        case 6:
            return Localizer.preLocalizedString(for: .saturday) ?? "Friday"
        case 7:
            return Localizer.preLocalizedString(for: .saturday) ?? "Saturday"
        default:
            return nil
        }
    }
    
    func separatorDateString() -> NSAttributedString {
        let calendar = Core.currentCalendar!
        let dateDifference = calendar.startOfDay(for: Date()).distance(to: calendar.startOfDay(for: self))
        
        let timeString = DateFormatter.localizedString(from: self,
                                                       dateStyle: .none,
                                                       timeStyle: .short)
        
        let overYearFormatter = DateFormatter()
        overYearFormatter.locale = Locale(identifier: RuntimeStorage.languageCode!)
        overYearFormatter.dateFormat = Locale.preferredLanguages[0] == "en-US" ? "MMM dd yyyy, " : "dd MMM yyyy, "
        
        let overYearString = overYearFormatter.string(from: self)
        
        let regularFormatter = DateFormatter()
        regularFormatter.locale = Locale(identifier: RuntimeStorage.languageCode!)
        regularFormatter.dateFormat = "yyyy-MM-dd"
        
        let underYearFormatter = DateFormatter()
        underYearFormatter.locale = Locale(identifier: RuntimeStorage.languageCode!)
        underYearFormatter.dateFormat = Locale.preferredLanguages[0] == "en-US" ? "E MMM d, " : "E d MMM, "
        
        let underYearString = underYearFormatter.string(from: self)
        
        if dateDifference == 0 {
            let separatorString = Localizer.preLocalizedString(for: .today) ?? "Today"
            
            return messagesAttributedString("\(separatorString) \(timeString)", separationIndex: separatorString.count)
        } else if dateDifference == -86400 {
            let separatorString = Localizer.preLocalizedString(for: .yesterday) ?? "Yesterday"
            
            return messagesAttributedString("\(separatorString) \(timeString)", separationIndex: separatorString.count)
        } else if dateDifference >= -604800 {
            guard let selfWeekday = self.dayOfWeek(),
                  let currentWeekday = Date().dayOfWeek() else {
                return messagesAttributedString(overYearString + timeString,
                                                separationIndex: overYearString.components(separatedBy: ",")[0].count + 1)
            }
            
            if selfWeekday != currentWeekday {
                return messagesAttributedString("\(selfWeekday) \(timeString)", separationIndex: selfWeekday.count)
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
public extension UIFont {
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
