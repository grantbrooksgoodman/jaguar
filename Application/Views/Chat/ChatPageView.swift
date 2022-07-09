//
//  ChatPageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 06/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import SwiftUI

/* Third-party Frameworks */
import InputBarAccessoryView
import MessageKit

//==================================================//

/* MARK: - Top-level Variable Declarations */

public var shouldReloadData = false

//==================================================//

/* MARK: - View Controller Declaration */

public final class MessageSwiftUIVC: MessagesViewController {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    var reloadTimer: Timer?
    
    //==================================================//
    
    /* MARK: - Overridden Functions */
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        becomeFirstResponder()
        messagesCollectionView.scrollToLastItem(animated: true)
        
        reloadTimer = Timer.scheduledTimer(timeInterval: 1,
                                           target: self,
                                           selector: #selector(reloadData),
                                           userInfo: nil, repeats: true)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        reloadTimer?.invalidate()
        reloadTimer = nil
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    @objc public func reloadData() {
        if shouldReloadData {
            self.messagesCollectionView.reloadData()
            self.messagesCollectionView.scrollToLastItem(animated: true)
            shouldReloadData = false
        }
    }
}

//==================================================//

/* MARK: - UIViewControllerRepresentable Declaration */

public struct ChatPageView: UIViewControllerRepresentable {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    @State var initialized = false
    @Binding var conversation: Conversation
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator(conversation: $conversation)
    }
    
    public func makeUIViewController(context: Context) -> MessagesViewController {
        let messagesVC = MessageSwiftUIVC()
        
        messagesVC.messagesCollectionView.messagesDisplayDelegate = context.coordinator
        messagesVC.messagesCollectionView.messagesLayoutDelegate = context.coordinator
        messagesVC.messagesCollectionView.messagesDataSource = context.coordinator
        messagesVC.messageInputBar.delegate = context.coordinator
        messagesVC.scrollsToLastItemOnKeyboardBeginsEditing = true // default false
        //messagesVC.maintainPositionOnInputBarHeightChanged = true // default false
        messagesVC.showMessageTimestampOnSwipeLeft = true // default false
        
        return messagesVC
    }
    
    public func updateUIViewController(_ uiViewController: MessagesViewController, context: Context) {
        uiViewController.messagesCollectionView.reloadData()
        scrollToBottom(uiViewController)
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func scrollToBottom(_ uiViewController: MessagesViewController) {
        DispatchQueue.main.async {
            // The initialized state variable allows us to start at the bottom with the initial messages without seeing the initial scroll flash by
            uiViewController.messagesCollectionView.scrollToLastItem(animated: self.initialized)
            self.initialized = true
        }
    }
    
    //==================================================//
    
    /* MARK: - Coordinator Class Declaration */
    
    public final class Coordinator {
        
        //==================================================//
        
        /* MARK: - Class-level Variable Declarations */
        
        public let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter
        }()
        
        public var conversation: Binding<Conversation>
        
        //==================================================//
        
        /* MARK: - Constructor Function */
        
        public init(conversation: Binding<Conversation>) {
            self.conversation = conversation
        }
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: MessagesDataSource */
extension ChatPageView.Coordinator: MessagesDataSource {
    
    public func currentSender() -> SenderType {
        return Sender(senderId: currentUserID, displayName: "??")
    }
    
    public func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return conversation.messages.wrappedValue.count
    }
    
    public func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return conversation.messages.wrappedValue[indexPath.section]
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

//extension TranslationPlatform {
//    func asString() -> String {
//        switch self {
//        case .azure:
//            return "Azure"
//        case .deepL:
//            return "DeepL"
//        case .google:
//            return "Google"
//        case .yandex:
//            return "Yandex"
//        case .random:
//            return "Random"
//        }
//    }
//}

/* MARK: InputBarAccessoryViewDelegate */
extension ChatPageView.Coordinator: InputBarAccessoryViewDelegate {
    
    public func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        inputBar.sendButton.startAnimating()
        inputBar.inputTextView.text = ""
        inputBar.inputTextView.placeholder = "Sending..."
        inputBar.inputTextView.tintColor = .clear
        
        TranslatorService.main.translate(TranslationInput(text),
                                         with: LanguagePair(from: currentUser!.languageCode,
                                                            to: conversation.wrappedValue.otherUser!.languageCode),
                                         using: .random) { (returnedTranslation, errorDescriptor) in
            inputBar.sendButton.stopAnimating()
            inputBar.inputTextView.placeholder = "Aa"
            inputBar.inputTextView.tintColor = .systemBlue
            
            guard returnedTranslation != nil || errorDescriptor != nil else {
                log("An unknown error occurred.",
                    metadata: [#file, #function, #line])
                
                AKAlert(message: "An unknown error occurred.",
                        cancelButtonTitle: "OK").present()
                return
            }
            
            if let error = errorDescriptor {
                log(error,
                    metadata: [#file, #function, #line])
                AKAlert(message: error,
                        cancelButtonTitle: "OK").present()
            } else if let translation = returnedTranslation {
                MessageSerializer.shared.createMessage(fromAccountWithIdentifier: currentUserID,
                                                       inConversationWithIdentifier: self.conversation.wrappedValue.identifier,
                                                       translation: translation) { (returnedMessage,
                                                                                    errorDescriptor) in
                    guard returnedMessage != nil || errorDescriptor != nil else {
                        log("An unknown error occurred.",
                            metadata: [#file, #function, #line])
                        AKAlert(title: "Couldn't Send Message",
                                message: "An unknown error occurred.",
                                cancelButtonTitle: "OK").present()
                        return
                    }
                    
                    if let error = errorDescriptor {
                        log(error,
                            metadata: [#file, #function, #line])
                        AKAlert(title: "Couldn't Send Message",
                                message: error,
                                cancelButtonTitle: "OK").present()
                    } else if let message = returnedMessage {
                        self.conversation.messages.wrappedValue?.append(message)
                        shouldReloadData = true
                    }
                }
            }
        }
    }
}

/* MARK: MessagesLayoutDelegate, MessagesDisplayDelegate */
extension ChatPageView.Coordinator: MessagesLayoutDelegate, MessagesDisplayDelegate {
    
}
