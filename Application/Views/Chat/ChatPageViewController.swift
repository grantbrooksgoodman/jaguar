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

import InputBarAccessoryView

public final class ChatPageViewController: MessagesViewController {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Booleans
    public var viewHasLaidOutSubviewsAtLeastOnce = false
    
    private var delegatesHaveBeenSet: Bool {
        get {
            return messagesCollectionView.messagesDataSource != nil &&
            messagesCollectionView.messagesDisplayDelegate != nil &&
            messagesCollectionView.messagesLayoutDelegate != nil &&
            messageInputBar.delegate != nil
        }
    }
    
    // Timers
    private var reloadTimer: Timer?
    private var typingIndicatorTimer: Timer?
    
    // Other
    public var progressView: UIProgressView?
    public var recipientBar: RecipientBar?
    
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
        
        if traitCollection.userInterfaceStyle == .dark {
            messageInputBar.backgroundView.backgroundColor = UIColor(hex: 0x1A1A1C)
        } else {
            Core.ui.setNavigationBarAppearance(backgroundColor: UIColor(hex: 0xF3F3F3),
                                               titleColor: .black)
            
            navigationController?.isNavigationBarHidden = true
            navigationController?.isNavigationBarHidden = false
        }
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(displayCustomMenu(gestureRecognizer:)))
        
        longPressGestureRecognizer.minimumPressDuration = 0.3
        longPressGestureRecognizer.delaysTouchesBegan = true
        
        messagesCollectionView.addGestureRecognizer(longPressGestureRecognizer)
        
        if RuntimeStorage.globalConversation?.identifier.key == "EMPTY" {
            recipientBar = RecipientBar(delegate: self)
            view.addSubview(recipientBar!)
            
            messagesCollectionView.contentInset.top = 54
            
            messageInputBar.inputTextView.placeholder = ""
            messageInputBar.sendButton.isEnabled = false
        }
        
        messageInputBar.inputTextView.delegate = self
        
        progressView = UIProgressView(frame: CGRect(x: 0,
                                                    y: 0,
                                                    width: UIScreen.main.bounds.width,
                                                    height: 2))
        progressView!.progressViewStyle = .bar
        progressView!.progress = 0
        view.addSubview(progressView!)
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        becomeFirstResponder()
        
        Core.gcd.after(seconds: 3) {
            self.reloadTimer = Timer.scheduledTimer(timeInterval: 1,
                                                    target: self,
                                                    selector: #selector(self.reloadData),
                                                    userInfo: nil,
                                                    repeats: true)
            
            self.typingIndicatorTimer = Timer.scheduledTimer(timeInterval: 1,
                                                             target: self,
                                                             selector: #selector(self.updateTypingIndicator),
                                                             userInfo: nil,
                                                             repeats: true)
        }
        
        Core.gcd.after(milliseconds: 500) {
            self.messagesCollectionView.scrollToLastItem(animated: true)
        }
        
        RuntimeStorage.store(true, as: .isPresentingChat)
        
        //        guard let conversation = RuntimeStorage.globalConversation,
        //              let otherUser = conversation.otherUser else { return }
        //
        //        if let image = ContactService.fetchContactThumbnail(forNumber: otherUser.phoneNumber) {
        //            let avatarImageView = UIImageView(image: image)
        //            avatarImageView.frame = CGRect(x: view.center.x,
        //                                           y: 0,
        //                                           width: 45,
        //                                           height: 45)
        //            avatarImageView.layer.cornerRadius = avatarImageView.frame.width / 2
        //            avatarImageView.clipsToBounds = true
        //
        //            guard let parent,
        //                  let navigationController = parent.navigationController else { return }
        //
        //            navigationController.navigationBar.addSubview(avatarImageView)
        //            navigationController.navigationBar.bringSubviewToFront(avatarImageView)
        //
        //            let navBarFrame = navigationController.navigationBar.frame
        //
        //            navigationController.navigationBar.frame = CGRect(x: navBarFrame.origin.x,
        //                                                              y: navBarFrame.origin.y - 3,
        //                                                              width: navBarFrame.width,
        //                                                              height: navBarFrame.height + 50)
        //            navigationController.navigationItem.leftBarButtonItem = UIBarButtonItem(image: image.withRenderingMode(.alwaysOriginal),
        //                                                                                    style: .plain,
        //                                                                                    target: self,
        //                                                                                    action: nil)
        //            navigationController.navigationBar.isHidden = false
        //        }
        
        print(messagesCollectionView.contentInset)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if !viewHasLaidOutSubviewsAtLeastOnce,
           RuntimeStorage.isPresentingChat!,
           delegatesHaveBeenSet {
            viewHasLaidOutSubviewsAtLeastOnce = true
            UIView.performWithoutAnimation { messageInputBar.becomeFirstResponder() }
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        reloadTimer?.invalidate()
        reloadTimer = nil
        
        typingIndicatorTimer?.invalidate()
        typingIndicatorTimer = nil
        
        Database.database().reference().removeAllObservers()
        
        RuntimeStorage.store(false, as: .isPresentingChat)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if let window = RuntimeStorage.topWindow!.subview(Core.ui.nameTag(for: "buildInfoOverlayWindow")) as? UIWindow {
            //            window.rootViewController = UIHostingController(rootView: BuildInfoOverlayView(yOffset: 0))
            window.isHidden = false
        }
        
        RuntimeStorage.store("ConversationsPageView.swift", as: .currentFile)
        
        Core.gcd.after(milliseconds: 250) {
            StateProvider.shared.hasDisappeared = true
        }
        
        RuntimeStorage.remove(.messagesVC)
        RuntimeStorage.store(0, as: .messageOffset)
        RuntimeStorage.remove(.globalConversation)
        RuntimeStorage.remove(.currentMessageSlice)
        RuntimeStorage.remove(.typingIndicator)
        
        messageInputBar.alpha = 0
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.userInterfaceStyle == .dark {
            messageInputBar.backgroundView.backgroundColor = UIColor(hex: 0x1A1A1C)
            Core.ui.setNavigationBarAppearance(backgroundColor: UIColor(hex: 0x2A2A2C),
                                               titleColor: .white)
            RuntimeStorage.messagesVC?.recipientBar?.updateAppearance()
        } else {
            messageInputBar.backgroundView.backgroundColor = .white
            Core.ui.setNavigationBarAppearance(backgroundColor: UIColor(hex: 0xF8F8F8),
                                               titleColor: .black)
            RuntimeStorage.messagesVC?.recipientBar?.updateAppearance()
        }
        
        navigationController?.isNavigationBarHidden = true
        navigationController?.isNavigationBarHidden = false
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
        guard RuntimeStorage.isPresentingChat!,
              delegatesHaveBeenSet else { return }
        
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
            
            RuntimeStorage.store(newMessageSlice, as: .currentMessageSlice)
            
            messagesCollectionView.reloadDataAndKeepOffset()
            loadedMore = Date()
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y < 0 && RuntimeStorage.isPresentingChat! {
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
            menuTitle = currentMessage.fromAccountIdentifier == RuntimeStorage.currentUserID! ? LocalizedString.viewOriginal : LocalizedString.viewTranslation
        } else {
            menuTitle = currentMessage.fromAccountIdentifier == RuntimeStorage.currentUserID! ? LocalizedString.viewTranslation : LocalizedString.viewOriginal
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
        guard RuntimeStorage.isPresentingChat!,
              delegatesHaveBeenSet else {
            reloadTimer?.invalidate()
            reloadTimer = nil
            return
        }
        
        if RuntimeStorage.shouldReloadData! {
            self.messagesCollectionView.reloadData()
            self.messagesCollectionView.scrollToLastItem(animated: true)
            RuntimeStorage.store(false, as: .shouldReloadData)
        }
    }
    
    @objc private func updateTypingIndicator() {
        guard RuntimeStorage.isPresentingChat!,
              delegatesHaveBeenSet else {
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

extension ChatPageViewController: UITextViewDelegate {
    public func textViewDidBeginEditing(_ textView: UITextView) {
        Core.gcd.after(milliseconds: 250) {
            self.messagesCollectionView.scrollToLastItem(animated: true)
        }
        
        print(messagesCollectionView.contentInset)
        
        guard let recipientBar = recipientBar else { return }
        recipientBar.deselectContact(animated: true)
    }
}

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

/* MARK: InputBarAccessoryView */
extension InputBarAccessoryView {
    override open var canBecomeFirstResponder: Bool {
        return RuntimeStorage.messagesVC?.viewHasLaidOutSubviewsAtLeastOnce ?? false
    }
}
