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
    
    @Binding var conversation: Conversation
    
    //==================================================//
    
    /* MARK: - Public Methods */
    
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
        //        messagesVC.maintainPositionOnKeyboardFrameChanged = true // default false
        //        messagesVC.maintainPositionOnKeyboardFrameChanged = true
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
        inputBar.inputTextView.placeholder = " \(LocalizedString.newMessage)"
        
        if Build.developerModeEnabled {
            let randomNumber = Int().random(min: 1, max: 999)
            let randomSentence = SentenceGenerator.generateSentence(wordCount: Int().random(min: 3, max: 15))
            inputBar.inputTextView.text = randomNumber % 2 == 0 ? randomSentence : ""
        }
        
        setUpNewMessageObserver()
        setUpReadDateObserver()
        setUpTypingIndicatorObserver()
        
        RuntimeStorage.store(#file, as: .currentFile)
        
        if let window = RuntimeStorage.topWindow!.subview(Core.ui.nameTag(for: "buildInfoOverlayWindow")) as? UIWindow {
            //            window.rootViewController = UIHostingController(rootView: BuildInfoOverlayView(yOffset: -20))
            window.isHidden = true
        }
        
        RuntimeStorage.store(messagesVC, as: .messagesVC)
        
        return messagesVC
    }
    
    public func updateUIViewController(_ uiViewController: MessagesViewController, context: Context) {
        guard RuntimeStorage.isPresentingChat! else { return }
        uiViewController.messagesCollectionView.reloadData()
    }
    
    //==================================================//
    
    /* MARK: - Observer Methods */
    
    private func setUpNewMessageObserver() {
        guard let conversation = RuntimeStorage.globalConversation else { return }
        let pathPrefix = "\(GeneralSerializer.environment.shortString)/conversations/"
        Database.database().reference().child("\(pathPrefix)\(conversation.identifier!.key!)/messages").observe(.childAdded) { (returnedSnapshot) in
            
            guard let identifier = returnedSnapshot.value as? String,
                  !conversation.messages.contains(where: { $0.identifier == identifier }) else { return }
            
            MessageSerializer.shared.getMessage(withIdentifier: identifier) { (returnedMessage,
                                                                               exception) in
                guard let message = returnedMessage else {
                    if let error = exception,
                       error.descriptor != "Null/first message processed." {
                        // #warning("Consistently getting no archive for language pair error on some accounts.")
                        Logger.log(error/*,
                                         with: .errorAlert*/)
                    }
                    
                    return
                }
                
                guard let currentUserID = RuntimeStorage.currentUserID,
                      message.fromAccountIdentifier != currentUserID else { return }
                
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
        // #warning("Such a broad observer isn't great for efficiency, but it may be the only way to do this with the current database scheme.") // correlate read date with last active date
        Database.database().reference().child(GeneralSerializer.environment.shortString).child("/messages").observe(.childChanged) { returnedSnapshot, _ in
            guard let lastMessage = conversation.sortedFilteredMessages().last else {
                let exception = Exception("Couldn't get last message.",
                                          extraParams: ["UnsortedMessageCount": conversation.messages.count,
                                                        "SortedMessageCount": conversation.sortedFilteredMessages().count],
                                          metadata: [#file, #function, #line])
                Logger.log(exception)
                return
            }
            
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  let data = snapshot as? [String: Any] else {
                Logger.log("Couldn't unwrap snapshot.",
                           with: .errorAlert,
                           metadata: [#file, #function, #line])
                return
            }
            
            guard returnedSnapshot.key == lastMessage.identifier else { return }
            
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
        guard let conversation = RuntimeStorage.globalConversation else { return }
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/conversations/"
        Database.database().reference().child("\(pathPrefix)\(conversation.identifier!.key!)/participants").observe(.childChanged) { (returnedSnapshot) in
            guard let updatedTyper = returnedSnapshot.value as? String,
                  updatedTyper.components(separatedBy: " | ")[0] != RuntimeStorage.currentUserID! else { return }
            
            RuntimeStorage.store(updatedTyper.components(separatedBy: " | ")[2] == "true",
                                 as: .typingIndicator)
        } withCancel: { (returnedError) in
            Logger.log(returnedError,
                       with: .errorAlert,
                       metadata: [#file, #function, #line])
        }
    }
}
