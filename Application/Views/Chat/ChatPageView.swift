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
        
        messagesVC.messagesCollectionView.messageCellDelegate = context.coordinator
        messagesVC.messagesCollectionView.messagesDataSource = context.coordinator
        messagesVC.messagesCollectionView.messagesDisplayDelegate = context.coordinator
        messagesVC.messagesCollectionView.messagesLayoutDelegate = context.coordinator
        
        messagesVC.messageInputBar.delegate = context.coordinator
        
        messagesVC.scrollsToLastItemOnKeyboardBeginsEditing = true
        messagesVC.showMessageTimestampOnSwipeLeft = true
        
        conversation.messages = conversation.sortedFilteredMessages()
        
        RuntimeStorage.store(conversation, as: .globalConversation)
        RuntimeStorage.store(RuntimeStorage.globalConversation!.get(.last, messages: 10), as: .currentMessageSlice)
        
        let inputBar = messagesVC.messageInputBar
        
        inputBar.inputTextView.clipsToBounds = true
        inputBar.inputTextView.layer.cornerRadius = 15
        inputBar.inputTextView.layer.borderColor = UIColor.systemGray.cgColor
        inputBar.inputTextView.layer.borderWidth = 0.5
        
        inputBar.sendButton.setImage(UIImage(named: "Send"), for: .normal)
        inputBar.sendButton.setImage(UIImage(named: "Send (Highlighted)"), for: .highlighted)
        
        inputBar.inputTextView.placeholder = " \(LocalizedString.newMessage)"
        
        if Build.developerModeEnabled {
            let randomNumber = Int().random(min: 1, max: 999)
            let randomSentence = SentenceGenerator.generateSentence(wordCount: Int().random(min: 3, max: 15))
            let shouldInsertRandomSentence = randomNumber % 2 == 0
            inputBar.inputTextView.text = shouldInsertRandomSentence ? randomSentence : ""
            
            if shouldInsertRandomSentence {
                Core.gcd.after(milliseconds: 200) { ChatServices.defaultChatUIService?.configureInputBar(forRecord: false) }
            }
        }
        
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
}
