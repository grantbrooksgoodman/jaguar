//
//  ChatPageViewController.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import FirebaseDatabase
import MessageKit

public final class ChatPageViewController: MessagesViewController,
                                           AudioMessageDelegate,
                                           MenuControllerDelegate,
                                           RetranslationDelegate {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Booleans
    public var viewHasLaidOutSubviewsAtLeastOnce = false
    
    private var configureInputBarForText: Bool { getConfigureInputBarForText() }
    private var delegatesHaveBeenSet: Bool { getDelegatesHaveBeenSet() }
    private var isLastCellVisible: Bool { getIsLastCellVisible() }
    private var otherUser: User? { getOtherUser() }
    
    // Timers
    private var reloadTimer: Timer?
    private var typingIndicatorTimer: Timer?
    
    // Other
    public var progressView: UIProgressView?
    public var recipientBar: RecipientBar?
    
    private var lastLoadedMoreMessages: Date! = Date().addingTimeInterval(-10)
    
    //==================================================//
    
    /* MARK: - View Lifecycle */
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        registerServices()
        
        configureBackgroundColor()
        configureCollectionViewLayout()
        configureInitialInputBar()
        updateAppearance(forTraitCollectionChange: false)
        configureMenuGestureRecognizer()
        configureProgressView()
        configureRecipientBar()
    }
    
    private func registerServices() {
        let audioMessageService = try? AudioMessageService(delegate: self)
        if let audioMessageService { ChatServices.register(service: audioMessageService) }
        
        let chatUIService = ChatUIService(delegate: self)
        ChatServices.register(service: chatUIService)
        
        let menuControllerService = try? MenuControllerService(delegate: self)
        if let menuControllerService { ChatServices.register(service: menuControllerService) }
        
        let observerService = try? ObserverService()
        if let observerService { ChatServices.register(service: observerService) }
        
        let retranslationService = try? RetranslationService(delegate: self)
        if let retranslationService { ChatServices.register(service: retranslationService) }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        RuntimeStorage.store(true, as: .isPresentingChat)
        DevModeService.removeAction(withTitle: "Show/Hide Build Info Overlay")
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        becomeFirstResponder()
        
        Core.gcd.after(seconds: 3) { self.configureTimers() }
        Core.gcd.after(milliseconds: 500) {
            guard self.delegatesHaveBeenSet else { return }
            self.messagesCollectionView.scrollToLastItem(animated: true)
        }
        
        Database.database().reference().removeAllObservers()
        
        ChatServices.observerService?.setUpNewMessageObserver()
        ChatServices.observerService?.setUpReadDateObserver()
        ChatServices.observerService?.setUpTypingIndicatorObserver()
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
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle ||
                RuntimeStorage.globalConversation?.identifier.key == "EMPTY" else { return }
        
        updateAppearance(forTraitCollectionChange: true)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        discardTimer(.both)
        
        Database.database().reference().removeAllObservers()
        
        ChatServices.menuControllerService?.stopSpeakingIfNeeded()
        ChatServices.audioMessageService?.removeRecordingUI()
        
        RuntimeStorage.store(false, as: .isPresentingChat)
        
        // #warning("Possibly redundant due to removeRecordingUI() call.")
        SpeechService.shared.stopRecording { fileURL, exception in
            guard let fileURL else {
                let error = exception ?? Exception(metadata: [#file, #function, #line])
                Logger.log(error,
                           verbose: error.isEqual(to: .noAudioRecorderToStop))
                return
            }
            
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch { Logger.log(Exception(error, metadata: [#file, #function, #line])) }
        }
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if let window = RuntimeStorage.topWindow!.subview(Core.ui.nameTag(for: "buildInfoOverlayWindow")) as? UIWindow {
            var shouldHide = UserDefaults.standard.value(forKey: "hidesBuildInfoOverlay") as? Bool
            shouldHide = shouldHide == nil ? true : shouldHide!
            window.isHidden = shouldHide!
        }
        
        ChatServices.menuControllerService?.resetAllAlternates()
        DevModeService.addStandardActions()
        
        RuntimeStorage.store("ConversationsPageView.swift", as: .currentFile)
        RuntimeStorage.topWindow?.isUserInteractionEnabled = false
        Core.gcd.after(milliseconds: 250) { StateProvider.shared.hasDisappeared = true }
        
        RuntimeStorage.remove(.messagesVC)
        RuntimeStorage.store(0, as: .messageOffset)
        RuntimeStorage.remove(.currentMessageSlice)
        RuntimeStorage.remove(.typingIndicator)
        
        messageInputBar.alpha = 0
    }
    
    //==================================================//
    
    /* MARK: - Computed Property Getters */
    
    private func getConfigureInputBarForText() -> Bool {
        guard let currentUser = RuntimeStorage.currentUser,
              let conversation = RuntimeStorage.globalConversation else { return true }
        
        guard currentUser.canSendAudioMessages else { return RuntimeStorage.acknowledgedAudioMessagesUnsupported! }
        
        guard let otherUser = conversation.otherUser else {
            guard conversation.identifier.key == "EMPTY" else { return true }
            return false
        }
        
        guard currentUser.canSendAudioMessages(to: otherUser) else { return true }
        
        return false
    }
    
    private func getDelegatesHaveBeenSet() -> Bool {
        messagesCollectionView.messagesDataSource != nil &&
        messagesCollectionView.messagesDisplayDelegate != nil &&
        messagesCollectionView.messagesLayoutDelegate != nil &&
        messageInputBar.delegate != nil
    }
    
    private func getIsLastCellVisible() -> Bool {
        guard let messages = RuntimeStorage.currentMessageSlice,
              !messages.isEmpty else { return true }
        
        let lastIndexPath = IndexPath(row: 0, section: messages.count - 1)
        guard let layoutAttributes = messagesCollectionView.layoutAttributesForItem(at: lastIndexPath) else { return true }
        
        var cellFrame = layoutAttributes.frame
        cellFrame.size.height = cellFrame.size.height // HUH??
        
        var cellRect = messagesCollectionView.convert(cellFrame, to: messagesCollectionView.superview)
        cellRect.origin.y = cellRect.origin.y - cellFrame.size.height - 100
        
        let bounds = messagesCollectionView.bounds
        var visibleRect = CGRect(x: bounds.origin.x,
                                 y: bounds.origin.y,
                                 width: bounds.size.width,
                                 height: bounds.size.height - messagesCollectionView.contentInset.bottom)
        visibleRect = messagesCollectionView.convert(visibleRect, to: messagesCollectionView.superview)
        
        guard CGRectContainsRect(visibleRect, cellRect) else { return false }
        return true
    }
    
    private func getOtherUser() -> User? {
        guard let contactNavigationRouterUser = ContactNavigationRouter.currentlySelectedUser else {
            guard let messagesVC = RuntimeStorage.messagesVC,
                  let recipientBar = messagesVC.recipientBar,
                  let selectedContactPair = recipientBar.selectedContactPair,
                  let numberPairs = selectedContactPair.numberPairs,
                  let recipientBarUser = numberPairs.first(where: { !$0.users.isEmpty })?.users.first else {
                
                guard let wrappedConversationUser = RuntimeStorage.coordinator?.conversation.wrappedValue.otherUser else {
                    guard let globalConversationUser = RuntimeStorage.globalConversation?.otherUser else { return nil }
                    return globalConversationUser
                }
                
                return wrappedConversationUser
            }
            
            return recipientBarUser
        }
        
        return contactNavigationRouterUser
    }
    
    //==================================================//
    
    /* MARK: - Menu Controller Gesture Recognizer Selector */
    
    @objc
    private func showMenu(_ recognizer: UIGestureRecognizer) {
        messageInputBar.tag = 86
        
        guard !messageInputBar.inputTextView.isFirstResponder else {
            messageInputBar.inputTextView.resignFirstResponder()
            ChatServices.menuControllerService?.hideMenuIfNeeded()
            return
        }
        
        let point = recognizer.location(in: messagesCollectionView)
        
        guard let indexPath = messagesCollectionView.indexPathForItem(at: point),
              let selectedCell = messagesCollectionView.cellForItem(at: indexPath) as? MessageContentCell,
              !RuntimeStorage.isSendingMessage! else { return }
        
        ChatServices.menuControllerService?.presentMenu(at: point, on: selectedCell)
    }
    
    //==================================================//
    
    /* MARK: - Timer Methods */
    
    /* Setup */
    
    private func configureTimers() {
        guard delegatesHaveBeenSet else {
            discardTimer(.both)
            return
        }
        
        guard reloadTimer == nil else {
            discardTimer(.reload)
            configureTimers()
            return
        }
        
        guard typingIndicatorTimer == nil else {
            discardTimer(.typingIndicator)
            configureTimers()
            return
        }
        
        reloadTimer = Timer.scheduledTimer(timeInterval: 1,
                                           target: self,
                                           selector: #selector(reloadData),
                                           userInfo: nil,
                                           repeats: true)
        
        typingIndicatorTimer = Timer.scheduledTimer(timeInterval: 1,
                                                    target: self,
                                                    selector: #selector(updateTypingIndicator),
                                                    userInfo: nil,
                                                    repeats: true)
    }
    
    private enum TimerType { case both; case reload; case typingIndicator }
    private func discardTimer(_ type: TimerType) {
        func discardReloadTimer() {
            reloadTimer?.invalidate()
            reloadTimer = nil
        }
        
        func discardTypingIndicatorTimer() {
            typingIndicatorTimer?.invalidate()
            typingIndicatorTimer = nil
        }
        
        switch type {
        case .both:
            discardReloadTimer()
            discardTypingIndicatorTimer()
        case .reload:
            discardReloadTimer()
        case .typingIndicator:
            discardTypingIndicatorTimer()
        }
    }
    
    /* Selectors */
    
    @objc
    private func reloadData() {
        guard RuntimeStorage.isPresentingChat!,
              delegatesHaveBeenSet else {
            discardTimer(.reload)
            return
        }
        
        guard RuntimeStorage.shouldReloadData!,
              !messagesCollectionView.isDragging,
              !messagesCollectionView.isTracking,
              !messagesCollectionView.isDecelerating,
              !AudioPlaybackController.isPlaying,
              !UIMenuController.shared.isMenuVisible else { return }
        
        messagesCollectionView.reloadData()
        messagesCollectionView.scrollToLastItem(animated: true)
        RuntimeStorage.store(false, as: .shouldReloadData)
    }
    
    @objc
    private func updateTypingIndicator() {
        guard RuntimeStorage.isPresentingChat!,
              delegatesHaveBeenSet else {
            discardTimer(.typingIndicator)
            return
        }
        
        guard !RuntimeStorage.isSendingMessage!,
              let messageSlice = RuntimeStorage.currentMessageSlice,
              let shouldShowIndicator = RuntimeStorage.typingIndicator else { return }
        
        guard !messagesCollectionView.isDragging,
              !messagesCollectionView.isTracking,
              !messagesCollectionView.isDecelerating,
              !AudioPlaybackController.isPlaying,
              !UIMenuController.shared.isMenuVisible,
              isLastCellVisible,
              messageSlice.count <= 5 else { return }
        
        defer { RuntimeStorage.remove(.typingIndicator) }
        
        guard shouldShowIndicator && isTypingIndicatorHidden else {
            guard !shouldShowIndicator && !isTypingIndicatorHidden else { return }
            setTypingIndicatorViewHidden(true, animated: false)
            
            return
        }
        
        setTypingIndicatorViewHidden(false, animated: false)
        messagesCollectionView.scrollToLastItem(animated: true)
    }
    
    //==================================================//
    
    /* MARK: - UI Configuration */
    
    private func configureBackgroundColor() {
        messagesCollectionView.backgroundColor = .encapsulatingViewBackgroundColor
        messagesCollectionView.backgroundView?.backgroundColor = .encapsulatingViewBackgroundColor
    }
    
    private func configureCollectionViewLayout() {
        guard let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout  else { return }
        layout.textMessageSizeCalculator.outgoingAvatarSize = .zero
        layout.audioMessageSizeCalculator.outgoingAvatarSize = .zero
        layout.setMessageOutgoingCellBottomLabelAlignment(.init(textAlignment: .right,
                                                                textInsets: .init(top: 2,
                                                                                  left: 0,
                                                                                  bottom: 0,
                                                                                  right: 10)))
    }
    
    private func configureInitialInputBar() {
        messageInputBar.sendButton.setSize(CGSize(width: 30, height: 30), animated: false)
        
        messageInputBar.setStackViewItems([messageInputBar.sendButton],
                                          forStack: .right,
                                          animated: false)
        
        messageInputBar.rightStackView.alignment = .center
        
        messageInputBar.contentView.clipsToBounds = true
        messageInputBar.contentView.layer.borderColor = configureInputBarForText ? UIColor.systemGray.cgColor : UIColor.clear.cgColor
        messageInputBar.contentView.layer.borderWidth = 0.5
        messageInputBar.contentView.layer.cornerRadius = 15
        
        messageInputBar.inputTextView.clipsToBounds = true
        messageInputBar.inputTextView.layer.borderColor = configureInputBarForText ? UIColor.clear.cgColor : UIColor.systemGray.cgColor
        messageInputBar.inputTextView.layer.borderWidth = 0.5
        messageInputBar.inputTextView.layer.cornerRadius = 15
        
        messageInputBar.sendButton.setImage(sendButtonImage(record: !configureInputBarForText), for: .normal)
        messageInputBar.sendButton.setImage(sendButtonImage(record: !configureInputBarForText, highlighted: true), for: .highlighted)
        messageInputBar.sendButton.tintColor = configureInputBarForText ? .systemBlue : .red
        
        messageInputBar.sendButton
            .onSelected { item in
                item.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }
            .onDeselected { item in item.transform = .identity }
        
        messageInputBar.inputTextView.delegate = self
        ChatServices.audioMessageService?.addGestureRecognizers()
    }
    
    private func configureMenuGestureRecognizer() {
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self,
                                                                      action: #selector(showMenu(_:)))
        longPressGestureRecognizer.minimumPressDuration = 0.3
        longPressGestureRecognizer.delaysTouchesBegan = true
        messagesCollectionView.addGestureRecognizer(longPressGestureRecognizer)
    }
    
    private func configureProgressView() {
        progressView = UIProgressView(frame: CGRect(x: 0,
                                                    y: 0,
                                                    width: UIScreen.main.bounds.width,
                                                    height: 2))
        progressView!.progressTintColor = .primaryAccentColor
        progressView!.progressViewStyle = .bar
        progressView!.progress = 0
        view.addSubview(progressView!)
    }
    
    private func configureRecipientBar() {
        guard RuntimeStorage.globalConversation?.identifier.key == "EMPTY",
              let contactPairs = RuntimeStorage.contactPairs else {
            messageInputBar.sendButton.isEnabled = (RuntimeStorage.coordinator?.shouldEnableSendButton ?? true)
            return
        }
        
        messagesCollectionView.contentInset.top = 54
        messageInputBar.inputTextView.placeholder = ""
        messageInputBar.sendButton.isEnabled = false
        
        recipientBar = RecipientBar(delegate: self, contactPairs: contactPairs)
        view.addSubview(recipientBar!)
    }
    
    private func sendButtonImage(record: Bool,
                                 highlighted: Bool = false) -> UIImage? {
        guard record else {
            let imageName = ThemeService.currentTheme != AppThemes.default ? "Send (Alternate\(highlighted ? " - Highlighted)" : ")")" : "Send\(highlighted ? " (Highlighted)" : "")"
            return UIImage(named: imageName)
        }
        
        return UIImage(named: "Record\(highlighted ? " (Highlighted)" : "")")
    }
    
    private func setTextInsets(for cell: TextMessageCell,
                               at indexPath: IndexPath) {
        guard ThemeService.currentTheme != AppThemes.default,
              let currentUserID = RuntimeStorage.currentUserID,
              let messageSlice = RuntimeStorage.currentMessageSlice,
              messageSlice.count > indexPath.section else { return }
        
        let currentMessage = messageSlice[indexPath.section]
        guard !currentMessage.isDisplayingAlternate else { return }
        
        guard currentMessage.fromAccountIdentifier == currentUserID else {
            cell.messageLabel.textInsets.left = 15
            return
        }
        
        cell.messageLabel.textInsets.right = 1
    }
    
    private func updateAppearance(forTraitCollectionChange: Bool) {
        messageInputBar.backgroundView.backgroundColor = .inputBarBackgroundColor
        
        guard forTraitCollectionChange else {
            guard traitCollection.userInterfaceStyle == .light else { return }
            Core.ui.setNavigationBarAppearance(backgroundColor: UIColor(hex: 0xF3F3F3),
                                               titleColor: .navigationBarTitleColor)
            navigationController?.isNavigationBarHidden = true
            navigationController?.isNavigationBarHidden = false
            return
        }
        
        Core.ui.setNavigationBarAppearance(backgroundColor: .navigationBarBackgroundColor,
                                           titleColor: .navigationBarTitleColor)
        recipientBar?.updateAppearance()
        
        navigationController?.isNavigationBarHidden = true
        navigationController?.isNavigationBarHidden = false
    }
    
    //==================================================//
    
    /* MARK: - UICollectionView Methods */
    
    public override func collectionView(_ collectionView: UICollectionView,
                                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let typingIndicatorCell = super.collectionView(collectionView, cellForItemAt: indexPath) as? TypingIndicatorCell {
            return typingIndicatorCell
        }
        
        guard let genericCell = super.collectionView(collectionView, cellForItemAt: indexPath) as? MessageCollectionViewCell else { return UICollectionViewCell() }
        genericCell.tag = indexPath.section
        
        guard let textCell = genericCell as? TextMessageCell,
              let messageSlice = RuntimeStorage.currentMessageSlice,
              messageSlice.count > indexPath.section else {
            return genericCell
        }
        
        let currentMessage = messageSlice[indexPath.section]
        setTextInsets(for: textCell, at: indexPath)
        
        guard currentMessage.isDisplayingAlternate else { return textCell }
        textCell.messageLabel.font = textCell.messageLabel.font.withTraits(traits: .traitItalic)
        
        guard textCell.messageContainerView.frame.size.height < 40 else { return textCell }
        textCell.messageContainerView.frame.size.width = textCell.messageLabel.intrinsicContentSize.width
        textCell.messageLabel.frame.size.width = textCell.messageLabel.intrinsicContentSize.width
        
        return textCell
    }
    
    //==================================================//
    
    /* MARK: - UIScrollView Methods */
    
    public override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y < 0 && RuntimeStorage.isPresentingChat! {
            loadMoreMessages(fromScrollToTop: false)
        }
    }
    
    public override func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        loadMoreMessages(fromScrollToTop: true)
    }
    
    private func loadMoreMessages(fromScrollToTop: Bool) {
        guard RuntimeStorage.isPresentingChat!,
              delegatesHaveBeenSet else { return }
        
        guard let offset = RuntimeStorage.messageOffset,
              let conversation = RuntimeStorage.globalConversation,
              let messageSlice = RuntimeStorage.currentMessageSlice else { return }
        
        if abs(lastLoadedMoreMessages.seconds(from: Date())) > 1 || fromScrollToTop {
            //Need to account for where conversation is short enough to be displayed fully on one page.
            guard offset + 10 < conversation.messages.count else { return }
            
            RuntimeStorage.store(offset + 10, as: .messageOffset)
            
            let newMessages = conversation.get(.last,
                                               messages: 10,
                                               offset: RuntimeStorage.messageOffset!)
            
            let oldMessageSlice = Array(messageSlice)
            
            var newMessageSlice = newMessages
            newMessageSlice.append(contentsOf: oldMessageSlice)
            newMessageSlice = newMessageSlice.unique()
            
            RuntimeStorage.store(newMessageSlice, as: .currentMessageSlice)
            
            messagesCollectionView.reloadDataAndKeepOffset()
            lastLoadedMoreMessages = Date()
        }
        
        if fromScrollToTop {
            messagesCollectionView.scrollToItem(at: IndexPath(row: 0, section: 0),
                                                at: .top,
                                                animated: true)
        }
    }
}

//==================================================//

/* MARK: - Protocol Conformances */

/* MARK: - ChatUIDelegate */
extension ChatPageViewController: ChatUIDelegate {
    
    // MARK: - Properties
    
    public var isUserCancellationEnabled: Bool {
        get {
            guard let parent,
                  let navigationController = parent.navigationController else { return false }
            
            guard navigationController.navigationBar.isUserInteractionEnabled,
                  let popGestureRecognizer = navigationController.interactivePopGestureRecognizer,
                  popGestureRecognizer.isEnabled else { return false }
            
            return true
        }
    }
    
    public var shouldShowRecordButton: Bool {
        get {
            guard let currentUser = RuntimeStorage.currentUser,
                  let otherUser,
                  currentUser.canSendAudioMessages else { return !RuntimeStorage.acknowledgedAudioMessagesUnsupported! }
            
            guard Capabilities.textToSpeechSupported(for: otherUser.languageCode) else { return false }
            return true
        }
    }
    
    // MARK: - Methods
    
    public func configureInputBar(forRecord: Bool) {
        guard forRecord else {
            guard messageInputBar.sendButton.isRecordButton else { return }
            messageInputBar.sendButton.gestureRecognizers?.removeAll()
            messageInputBar.sendButton.tag = 0
            
            UIView.transition(with: messageInputBar.sendButton,
                              duration: 0.3,
                              options: [.transitionCrossDissolve]) {
                self.messageInputBar.inputTextView.layer.borderColor = UIColor.clear.cgColor
                self.messageInputBar.contentView.layer.borderColor = UIColor.systemGray.cgColor
                
                self.messageInputBar.sendButton.setImage(self.sendButtonImage(record: false), for: .normal)
                self.messageInputBar.sendButton.setImage(self.sendButtonImage(record: false, highlighted: true), for: .highlighted)
                self.messageInputBar.sendButton.tintColor = .primaryAccentColor
            }
            
            return
        }
        
        guard !messageInputBar.sendButton.isRecordButton else { return }
        messageInputBar.sendButton.tag = Core.ui.nameTag(for: "recordButton")
        
        UIView.transition(with: messageInputBar.sendButton,
                          duration: 0.3,
                          options: [.transitionCrossDissolve]) {
            self.messageInputBar.contentView.layer.borderColor = UIColor.clear.cgColor
            self.messageInputBar.inputTextView.layer.borderColor = UIColor.systemGray.cgColor
            
            self.messageInputBar.sendButton.setImage(self.sendButtonImage(record: true), for: .normal)
            self.messageInputBar.sendButton.setImage(self.sendButtonImage(record: true, highlighted: true), for: .highlighted)
            self.messageInputBar.sendButton.tintColor = .red
            
            ChatServices.audioMessageService?.addGestureRecognizers()
        }
    }
    
    public func hideNewChatControls() {
        DispatchQueue.main.async {
            // #warning("Do we want to couple these guard conditions?")
            guard let pair = self.recipientBar?.selectedContactPair else { return }
            
            self.recipientBar?.removeFromSuperview()
            self.messagesCollectionView.contentInset.top = 0
            self.messagesCollectionView.isUserInteractionEnabled = true
            
            guard let parent = self.parent else { return }
            
            parent.navigationItem.title = "\(pair.contact.firstName) \(pair.contact.lastName)"
            
            let doneButton = UIBarButtonItem(title: LocalizedString.done,
                                             style: .done,
                                             target: self,
                                             action: #selector(ChatServices.chatUIService?.toggleDoneButton))
            doneButton.tag = Core.ui.nameTag(for: "doneButton")
            doneButton.isEnabled = false
            parent.navigationItem.rightBarButtonItems = [doneButton]
        }
    }
    
    public func setUserCancellation(enabled: Bool) {
        guard let parent = parent else { return }
        
        parent.navigationController?.navigationBar.isUserInteractionEnabled = enabled
        parent.navigationController?.interactivePopGestureRecognizer?.isEnabled = enabled
        
        guard recipientBar != nil else { return }
        
        let barButton: UIBarButtonItem!
        
        defer {
            barButton.isEnabled = enabled
            parent.navigationItem.rightBarButtonItems = [barButton]
        }
        
        guard let buttons = parent.navigationItem.rightBarButtonItems,
              !buttons.isEmpty,
              buttons[0].tag == Core.ui.nameTag(for: "doneButton") else {
            barButton = UIBarButtonItem(title: LocalizedString.cancel,
                                        style: .plain,
                                        target: self,
                                        action: #selector(self.toggleDoneButton))
            barButton.tintColor = .primaryAccentColor
            barButton.tag = Core.ui.nameTag(for: "cancelButton")
            return
        }
        
        barButton = UIBarButtonItem(title: LocalizedString.done,
                                    style: .done,
                                    target: self,
                                    action: #selector(self.toggleDoneButton))
        barButton.tintColor = .primaryAccentColor
        barButton.tag = Core.ui.nameTag(for: "doneButton")
    }
    
    @objc
    public func toggleDoneButton() {
        messageInputBar.inputTextView.resignFirstResponder()
        StateProvider.shared.tappedDone = true
    }
}

/* MARK: UITextViewDelegate */
extension ChatPageViewController: UITextViewDelegate {
    
    // MARK: - Properties
    
    override public var textInputMode: UITextInputMode? {
        guard let currentUser = RuntimeStorage.currentUser else { return nil }
        
        var match: UITextInputMode?
        for mode in UITextInputMode.activeInputModes {
            guard let primaryLanguage = mode.primaryLanguage,
                  primaryLanguage.lowercased().hasPrefix(currentUser.languageCode) else { continue }
            match = mode
        }
        
        return match
    }
    
    // MARK: - Methods
    
    public func textView(_ textView: UITextView,
                         shouldChangeTextIn range: NSRange,
                         replacementText text: String) -> Bool {
        guard let recordingView = messageInputBar.contentView.subview(for: "recordingView"),
              recordingView.alpha == 1 else {
            guard self.messageInputBar.inputTextView.alpha == 0 || RuntimeStorage.isSendingMessage! else { return true }
            return false
        }
        
        return false
    }
    
    public func textViewDidBeginEditing(_ textView: UITextView) {
        messageInputBar.tag = 88
        
        Core.gcd.after(milliseconds: 250) {
            guard self.delegatesHaveBeenSet else { return }
            self.messagesCollectionView.scrollToLastItem(animated: true)
        }
        
        UIMenuController.shared.menuItems = nil
        ChatServices.menuControllerService?.hideMenuIfNeeded()
        
        guard let recipientBar = recipientBar else { return }
        recipientBar.deselectContact(animated: true)
    }
    
    public func textViewDidChange(_ textView: UITextView) {
        configureInputBar(forRecord: textView.text == nil)
    }
}
