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
import Translator

public final class ChatPageViewController: MessagesViewController {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    //Timers
    var reloadTimer: Timer?
    var typingIndicatorTimer: Timer?
    
    //Other Declarations
    var selectedCell: TextMessageCell?
    
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
        reloadTimer?.invalidate()
        reloadTimer = nil
        
        typingIndicatorTimer?.invalidate()
        typingIndicatorTimer = nil
        
        Database.database().reference().removeAllObservers()
    }
    
    public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let typingIndicatorCell = super.collectionView(collectionView, cellForItemAt: indexPath) as? TypingIndicatorCell {
            return typingIndicatorCell
        }
        
        let currentCell = super.collectionView(collectionView, cellForItemAt: indexPath) as! MessageCollectionViewCell
        
        currentCell.tag = indexPath.section
        
        guard topLevelMessages.count > indexPath.section else {
            return currentCell
        }
        
        if topLevelMessages[indexPath.section].isDisplayingAlternate,
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
    
    /* MARK: - Other Functions */
    
    @objc private func displayCustomMenu(gestureRecognizer: UIGestureRecognizer) {
        guard !UIMenuController.shared.isMenuVisible else {
            return
        }
        
        messageInputBar.inputTextView.resignFirstResponder()
        
        let point = gestureRecognizer.location(in: messagesCollectionView)
        
        guard let indexPath = messagesCollectionView.indexPathForItem(at: point),
              let cell = messagesCollectionView.cellForItem(at: indexPath) as? TextMessageCell else {
            return
        }
        
        let currentMessage = topLevelMessages[indexPath.section]
        var menuTitle: String!
        
        if currentMessage.isDisplayingAlternate {
            menuTitle = currentMessage.fromAccountIdentifier == currentUserID ? "View Original" : "View Translation"
        } else {
            menuTitle = currentMessage.fromAccountIdentifier == currentUserID ? "View Translation" : "View Original"
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
        
        for (index, message) in topLevelMessages.enumerated() {
            if message.isDisplayingAlternate {
                indexPaths.append(IndexPath(row: 0, section: index))
            }
        }
        
        return indexPaths
    }
    
    @objc private func reloadData() {
        if shouldReloadData {
            self.messagesCollectionView.reloadData()
            self.messagesCollectionView.scrollToLastItem(animated: true)
            shouldReloadData = false
        }
    }
    
    @objc private func updateTypingIndicator() {
        if let indicator = typingIndicator {
            self.setTypingIndicatorViewHidden(!indicator, animated: true)
            self.messagesCollectionView.scrollToLastItem(animated: true)
            typingIndicator = nil
        }
    }
    
    @objc private func viewAlternate() {
        guard let cell = selectedCell else {
            return
        }
        
        var paths = indexPaths()
        paths.append(IndexPath(row: 0, section: cell.tag))
        paths = paths.unique()
        
        let message = topLevelMessages[cell.tag]
        
        let input = message.translation.input
        message.translation.input = TranslationInput(message.translation.output)
        message.translation.output = input.value()
        
        message.isDisplayingAlternate = !message.isDisplayingAlternate
        
        messagesCollectionView.reloadItems(at: paths)
        
        selectedCell = nil
    }
}
