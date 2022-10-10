//
//  ChatPageViewController.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import Firebase
import FirebaseDatabase
import MessageKit
import SwiftUI
import Translator

public final class ChatPageViewController: MessagesViewController {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Timers
    private var reloadTimer: Timer?
    private var typingIndicatorTimer: Timer?
    
    // Other
    private var loadedMore: Date! = Date().addingTimeInterval(-10)
    private var selectedCell: TextMessageCell?
    
    //==================================================//
    
    /* MARK: - Overridden Functions */
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        if let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout {
            layout.textMessageSizeCalculator.outgoingAvatarSize = .zero
            layout.setMessageOutgoingCellBottomLabelAlignment(.init(textAlignment: .right,
                                                                    textInsets: .init(top: 2,
                                                                                      left: 0,
                                                                                      bottom: 0,
                                                                                      right: 10)))
        }
        
        messageInputBar.sendButton.setSize(CGSize(width: 25, height: 25), animated: false)
        messageInputBar.setStackViewItems([.fixedSpace(15), messageInputBar.sendButton], forStack: .right, animated: false)
        messageInputBar.rightStackView.alignment = .center
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(displayCustomMenu(gestureRecognizer:)))
        
        longPressGestureRecognizer.minimumPressDuration = 0.3
        longPressGestureRecognizer.delaysTouchesBegan = true
        
        messagesCollectionView.addGestureRecognizer(longPressGestureRecognizer)
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        becomeFirstResponder()
        messagesCollectionView.scrollToLastItem(animated: true)
        
        reloadTimer = Timer.scheduledTimer(timeInterval: 1,
                                           target: self,
                                           selector: #selector(reloadData),
                                           userInfo: nil, repeats: true)
        
        typingIndicatorTimer = Timer.scheduledTimer(timeInterval: 1,
                                                    target: self,
                                                    selector: #selector(updateTypingIndicator),
                                                    userInfo: nil, repeats: true)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        reloadTimer?.invalidate()
        reloadTimer = nil
        
        typingIndicatorTimer?.invalidate()
        typingIndicatorTimer = nil
        
        Database.database().reference().removeAllObservers()
        
        RuntimeStorage.store(0, as: .messageOffset)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if let window = RuntimeStorage.topWindow!.subview(Core.ui.nameTag(for: "buildInfoOverlayWindow")) as? UIWindow {
            //            window.rootViewController = UIHostingController(rootView: BuildInfoOverlayView(yOffset: 0))
            window.isHidden = false
        }
    }
    
    //==================================================//
    
    /* MARK: - UICollectionView Functions */
    
    public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let typingIndicatorCell = super.collectionView(collectionView, cellForItemAt: indexPath) as? TypingIndicatorCell {
            return typingIndicatorCell
        }
        
        let currentCell = super.collectionView(collectionView, cellForItemAt: indexPath) as! MessageCollectionViewCell
        currentCell.tag = indexPath.section
        
        guard RuntimeStorage.currentMessageSlice!.count > indexPath.section else {
            return currentCell
        }
        
        if RuntimeStorage.currentMessageSlice![indexPath.section].isDisplayingAlternate,
           let cell = currentCell as? TextMessageCell {
            cell.messageLabel.font = cell.messageLabel.font.withTraits(traits: .traitItalic)
            
            if cell.messageContainerView.frame.size.height == 36 {
                cell.messageContainerView.frame.size.width = cell.messageLabel.intrinsicContentSize.width
                cell.messageLabel.frame.size.width = cell.messageLabel.intrinsicContentSize.width
            }
        }
        
        return currentCell
    }
    
    //==================================================//
    
    /* MARK: - UIScrollView Functions */
    
    private func loadMoreMessages() {
        if abs(loadedMore.amountOfSeconds(from: Date())) > 2 {
            //Need to account for where conversation is short enough to be displayed fully on one page.
            guard RuntimeStorage.messageOffset! + 10 < RuntimeStorage.globalConversation!.messages.count else {
                return
            }
            
            RuntimeStorage.store(RuntimeStorage.messageOffset! + 10, as: .messageOffset)
            
            let newMessages = RuntimeStorage.globalConversation!.get(.last,
                                                                     messages: 10,
                                                                     offset: RuntimeStorage.messageOffset!)
            
            let oldMessageSlice = Array(RuntimeStorage.currentMessageSlice!)
            
            var newMessageSlice = newMessages
            newMessageSlice.append(contentsOf: oldMessageSlice)
            newMessageSlice = newMessageSlice.unique()
            
            RuntimeStorage.store(newMessages, as: .currentMessageSlice)
            
            messagesCollectionView.reloadDataAndKeepOffset()
            loadedMore = Date()
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y < 0 {
            loadMoreMessages()
        }
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView,
                                         willDecelerate decelerate: Bool) {
        //        print("ended dragging")
    }
    
    public func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        loadMoreMessages()
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    @objc private func displayCustomMenu(gestureRecognizer: UIGestureRecognizer) {
        let point = gestureRecognizer.location(in: messagesCollectionView)
        
        guard let indexPath = messagesCollectionView.indexPathForItem(at: point),
              let cell = messagesCollectionView.cellForItem(at: indexPath) as? TextMessageCell else {
            return
        }
        
        let currentMessage = RuntimeStorage.currentMessageSlice![indexPath.section]
        
        guard !UIMenuController.shared.isMenuVisible,
              currentMessage.identifier != "NEW" else {
            return
        }
        
        messageInputBar.inputTextView.resignFirstResponder()
        
        var menuTitle: String!
        
        if currentMessage.isDisplayingAlternate {
            menuTitle = currentMessage.fromAccountIdentifier == RuntimeStorage.currentUserID! ? "View Original" : "View Translation"
        } else {
            menuTitle = currentMessage.fromAccountIdentifier == RuntimeStorage.currentUserID! ? "View Translation" : "View Original"
        }
        
        let viewAlternateItem = UIMenuItem(title: menuTitle, action: #selector(viewAlternate))
        UIMenuController.shared.menuItems = [viewAlternateItem]
        
        selectedCell = cell
        
        let convertedPoint = messagesCollectionView.convert(point, to: cell.messageContainerView)
        
        if cell.messageContainerView.bounds.contains(convertedPoint) {
            messagesCollectionView.becomeFirstResponder()
            UIMenuController.shared.showMenu(from: messagesCollectionView, rect: CGRect(x: point.x,
                                                                                        y: cell.frame.minY + 2,
                                                                                        width: 20,
                                                                                        height: 20))
        }
    }
    
    private func indexPaths() -> [IndexPath] {
        var indexPaths = [IndexPath]()
        
        for (index, message) in RuntimeStorage.currentMessageSlice!.enumerated() {
            if message.isDisplayingAlternate {
                indexPaths.append(IndexPath(row: 0, section: index))
            }
        }
        
        return indexPaths
    }
    
    @objc private func reloadData() {
        if RuntimeStorage.shouldReloadData! {
            self.messagesCollectionView.reloadData()
            self.messagesCollectionView.scrollToLastItem(animated: true)
            RuntimeStorage.store(false, as: .shouldReloadData)
        }
    }
    
    @objc private func updateTypingIndicator() {
        guard isFirstResponder else {
            typingIndicatorTimer?.invalidate()
            typingIndicatorTimer = nil
            return
        }
        
        if let indicator = RuntimeStorage.typingIndicator {
            if !messagesCollectionView.isDragging &&
                !messagesCollectionView.isTracking &&
                !messagesCollectionView.isDecelerating {
                setTypingIndicatorViewHidden(!indicator, animated: false)
                messagesCollectionView.scrollToLastItem(animated: false)
                RuntimeStorage.remove(.typingIndicator)
            }
        }
    }
    
    @objc private func viewAlternate() {
        guard let cell = selectedCell else {
            return
        }
        
        var paths = indexPaths()
        paths.append(IndexPath(row: 0, section: cell.tag))
        paths = paths.unique()
        
        let message = RuntimeStorage.currentMessageSlice![cell.tag]
        
        let input = message.translation.input
        message.translation.input = TranslationInput(message.translation.output)
        message.translation.output = input.value()
        
        message.isDisplayingAlternate = !message.isDisplayingAlternate
        
        messagesCollectionView.reloadItems(at: paths)
        
        selectedCell = nil
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Array */
public extension Array where Element == Message {
    func unique() -> [Message] {
        var uniqueValues = [Message]()
        
        for message in self {
            if !uniqueValues.contains(where: { $0.identifier == message.identifier }) {
                uniqueValues.append(message)
            }
        }
        
        return uniqueValues
    }
}
