//
//  ChatPageViewController.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import AVFoundation

/* Third-party Frameworks */
import Firebase
import FirebaseDatabase
import InputBarAccessoryView
import MessageKit
import Translator

public final class ChatPageViewController: MessagesViewController, AVSpeechSynthesizerDelegate {
    
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
    private var speechSynthesizer: AVSpeechSynthesizer!
    
    private var isLastCellVisible: Bool {
        guard let messages = RuntimeStorage.currentMessageSlice,
              !messages.isEmpty else { return true }
        
        let lastIndexPath = IndexPath(row: 0, section: messages.count - 1)
        guard let layoutAttributes = messagesCollectionView.layoutAttributesForItem(at: lastIndexPath) else { return true }
        var cellFrame = layoutAttributes.frame
        
        cellFrame.size.height = cellFrame.size.height
        
        var cellRect = messagesCollectionView.convert(cellFrame, to: messagesCollectionView.superview)
        
        cellRect.origin.y = cellRect.origin.y - cellFrame.size.height - 100
        // substract 100 to make the "visible" area of a cell bigger
        
        var visibleRect = CGRectMake(
            messagesCollectionView.bounds.origin.x,
            messagesCollectionView.bounds.origin.y,
            messagesCollectionView.bounds.size.width,
            messagesCollectionView.bounds.size.height - messagesCollectionView.contentInset.bottom
        )
        
        visibleRect = messagesCollectionView.convert(visibleRect, to: messagesCollectionView.superview)
        
        if CGRectContainsRect(visibleRect, cellRect) {
            return true
        }
        
        return false
    }
    
    //==================================================//
    
    /* MARK: - Overridden Methods */
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        speechSynthesizer = AVSpeechSynthesizer()
        speechSynthesizer.delegate = self
        
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
        
        messageInputBar.inputTextView.delegate = self
        
        progressView = UIProgressView(frame: CGRect(x: 0,
                                                    y: 0,
                                                    width: UIScreen.main.bounds.width,
                                                    height: 2))
        progressView!.progressViewStyle = .bar
        progressView!.progress = 0
        view.addSubview(progressView!)
        
        /* For new chats */
        guard RuntimeStorage.globalConversation?.identifier.key == "EMPTY",
              let contactPairs = RuntimeStorage.contactPairs else { return }
        
        messagesCollectionView.contentInset.top = 54
        
        recipientBar = RecipientBar(delegate: self,
                                    contactPairs: contactPairs)
        view.addSubview(recipientBar!)
        
        messageInputBar.inputTextView.placeholder = ""
        messageInputBar.sendButton.isEnabled = false
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
        
        //        print(messagesCollectionView.contentInset)
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
        
        speechSynthesizer.stopSpeaking(at: .immediate)
        
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
    
    /* MARK: - Message Retranslation */
    
    private func displayRetranslation(_ translation: Translation,
                                      message: Message,
                                      indexPath: Int) {
        Core.hud.hide()
        
        guard let messageSlice = RuntimeStorage.currentMessageSlice,
              let conversation = RuntimeStorage.globalConversation,
              let currentUser = RuntimeStorage.currentUser else { return }
        
        message.translation = translation
        message.languagePair = translation.languagePair
        
        message.updateLanguagePair(translation.languagePair) { exception in
            guard exception == nil else {
                Core.hud.hide()
                Logger.log(exception!,
                           with: .errorAlert)
                return
            }
            
            let storedMessage = conversation.messages.filter({ $0.identifier == message.identifier }).first!
            storedMessage.translation = translation
            storedMessage.languagePair = translation.languagePair
            
            let sliceMessage = messageSlice.filter({ $0.identifier == message.identifier }).first!
            sliceMessage.translation = translation
            sliceMessage.languagePair = translation.languagePair
            
            ConversationArchiver.clearArchive()
            ConversationArchiver.addToArchive(conversation)
            
            guard var conversations = currentUser.openConversations else {
                Core.hud.hide()
                Logger.log("Couldn't retrieve conversations from RuntimeStorage.",
                           with: .errorAlert,
                           metadata: [#file, #function, #line])
                return
            }
            
            conversations = conversations.filter({ $0.identifier.key != conversation.identifier.key })
            conversations.append(conversation)
            currentUser.openConversations = conversations
            
            //            let updatedMessageSlice = RuntimeStorage.globalConversation!.get(.last,
            //                                                                             messages: 10,
            //                                                                             offset: RuntimeStorage.messageOffset!)
            
            //            RuntimeStorage.store(updatedMessageSlice, as: .currentMessageSlice)
            //            RuntimeStorage.store(true, as: .shouldReloadData)
            
            self.messagesCollectionView.reloadItems(at: [IndexPath(row: 0, section: indexPath)])
            self.selectedCell = nil
        }
    }
    
    @objc private func retryTranslationSelector() {
        hideMenuIfVisible()
        
        guard let cell = selectedCell else { return }
        
        guard let conversation = RuntimeStorage.globalConversation,
              let currentUser = RuntimeStorage.currentUser,
              let currentUserID = RuntimeStorage.currentUserID,
              let messageSlice = RuntimeStorage.currentMessageSlice,
              let otherUser = conversation.otherUser else { return }
        
        let message = messageSlice[cell.tag]
        
        // delete the translation on the server and from archive
        // retry with google, then with deepL
        // if unable alert, if got it then reload with new translation
        // the hashes will remain the same because it's the same input value.
        
        let translation = message.translation!
        guard translation.input.value() == translation.output else { return }
        
        let pair = translation.languagePair
        
        var languagePair = pair
        
        if message.fromAccountIdentifier == currentUserID {
            languagePair = pair.from == pair.to ? LanguagePair(from: currentUser.languageCode,
                                                               to: pair.to) : pair
            if languagePair.from == languagePair.to {
                languagePair = LanguagePair(from: currentUser.languageCode,
                                            to: otherUser.languageCode)
            }
        } else {
            languagePair = pair.from == pair.to ? LanguagePair(from: pair.from,
                                                               to: currentUser.languageCode) : pair
            
            if languagePair.from == languagePair.to {
                languagePair = LanguagePair(from: otherUser.languageCode,
                                            to: currentUser.languageCode)
            }
        }
        
        translation.languagePair = languagePair
        
        Logger.log("Wants to retry translation on message from \(languagePair.from) to \(languagePair.to).",
                   metadata: [#file, #function, #line])
        
        Core.hud.showProgress()
        
        TranslationSerializer.removeTranslation(for: translation.input,
                                                languagePair: translation.languagePair) { exception in
            guard exception == nil else {
                Core.hud.hide()
                Logger.log(exception!,
                           with: .errorAlert)
                return
            }
            
            TranslationArchiver.clearArchive()
            
            Logger.openStream(message: "Retrying translation using Google...",
                              metadata: [#file, #function, #line])
            
            self.retryTranslation(translation,
                                  using: .google) { returnedTranslation, exception in
                guard let translation = returnedTranslation else {
                    let error = exception ?? Exception(metadata: [#file, #function, #line])
                    if error.descriptor == "Translation result is still the same." {
                        Logger.logToStream("Same translation – trying DeepL...",
                                           line: #line)
                        
                        TranslationSerializer.removeTranslation(for: translation.input,
                                                                languagePair: translation.languagePair) { exception in
                            guard exception == nil else {
                                Core.hud.hide()
                                Logger.log(exception!,
                                           with: .errorAlert)
                                return
                            }
                            
                            TranslationArchiver.clearArchive()
                            
                            self.retryTranslation(translation,
                                                  using: .deepL) { returnedTranslation, exception in
                                guard let translation = returnedTranslation else {
                                    let error = exception ?? Exception(metadata: [#file, #function, #line])
                                    if error.descriptor == "Translation result is still the same." {
                                        Logger.logToStream("Same translation – trying English method...",
                                                           line: #line)
                                        
                                        self.retryToEnglishAndStop(translation,
                                                                   message: message,
                                                                   indexPath: cell.tag)
                                    } else {
                                        Core.hud.hide()
                                        Logger.log(error,
                                                   with: .errorAlert)
                                    }
                                    
                                    return
                                }
                                
                                Logger.closeStream(message: "Got proper translation from DeepL!",
                                                   onLine: #line)
                                
                                self.displayRetranslation(translation,
                                                          message: message,
                                                          indexPath: cell.tag)
                            }
                        }
                    } else {
                        Core.hud.hide()
                        Logger.log(error,
                                   with: .errorAlert)
                    }
                    
                    return
                }
                
                Logger.closeStream(message: "Got proper translation from Google!",
                                   onLine: #line)
                
                self.displayRetranslation(translation,
                                          message: message,
                                          indexPath: cell.tag)
            }
        }
    }
    
    private func retryToEnglishAndStop(_ originalTranslation: Translation,
                                       message: Message,
                                       indexPath: Int) {
        let originalLanguagePair = originalTranslation.languagePair
        
        TranslationSerializer.removeTranslation(for: originalTranslation.input,
                                                languagePair: originalTranslation.languagePair) { exception in
            guard exception == nil else {
                Logger.closeStream()
                Core.hud.hide()
                Logger.log(exception!,
                           with: .errorAlert)
                return
            }
            
            TranslationArchiver.clearArchive()
            
            FirebaseTranslator.shared.translate(originalTranslation.input,
                                                with: LanguagePair(from: originalLanguagePair.from, to: "en")) { toEnglish, exception in
                guard let toEnglish else {
                    Logger.closeStream()
                    Core.hud.hide()
                    Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                               with: .errorAlert)
                    return
                }
                
                FirebaseTranslator.shared.translate(TranslationInput(toEnglish.output),
                                                    with: LanguagePair(from: "en", to: originalLanguagePair.to)) { toDesired, exception in
                    guard let toDesired else {
                        Logger.closeStream()
                        Core.hud.hide()
                        Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                                   with: .errorAlert)
                        return
                    }
                    
                    if let language = RecognitionService.detectedLanguage(for: toDesired.output),
                       language != originalLanguagePair.to {
                        let desiredString = Locale.current.localizedString(forIdentifier: originalLanguagePair.to)
                        let detectedString = Locale.current.localizedString(forIdentifier: language)
                        
                        Logger.closeStream(message: "English method yielded wrong language output.\nDesired: \(desiredString ?? "")\nGot: \(detectedString ?? "")\nOriginally From: \(originalLanguagePair.from)\nInput: \(originalTranslation.input.value())\nOutput: \(toDesired.output)",
                                           onLine: #line)
                        
                        Core.hud.hide()
                        Logger.log(Exception("Failed to retranslate.",
                                             metadata: [#file, #function, #line]),
                                   with: .errorAlert)
                    } else {
                        let desiredString = Locale.current.localizedString(forIdentifier: originalLanguagePair.to)
                        
                        Logger.logToStream("Desired: \(desiredString ?? "")\nOriginally From: \(originalLanguagePair.from)\nInput: \(originalTranslation.input.value())\nOutput: \(toDesired.output)",
                                           line: #line)
                        
                        let mutantTranslation = Translation(input: originalTranslation.input,
                                                            output: toDesired.output.matchingCapitalization(of: originalTranslation.input.value()),
                                                            languagePair: originalLanguagePair)
                        
                        TranslationSerializer.uploadTranslation(mutantTranslation)
                        TranslationArchiver.addToArchive(mutantTranslation)
                        
                        Logger.closeStream(message: "Got proper translation from English method!",
                                           onLine: #line)
                        
                        self.displayRetranslation(mutantTranslation,
                                                  message: message,
                                                  indexPath: indexPath)
                    }
                }
            }
        }
    }
    
    private func retryTranslation(_ translation: Translation,
                                  using: TranslationPlatform,
                                  completion: @escaping(_ returnedTranslation: Translation?,
                                                        _ exception: Exception?) -> Void) {
        TranslationArchiver.clearArchive()
        
        FirebaseTranslator.shared.translate(translation.input,
                                            with: translation.languagePair,
                                            using: using) { returnedTranslation, exception in
            guard let translation = returnedTranslation else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            guard translation.input.value() != translation.output else {
                completion(nil, Exception("Translation result is still the same.",
                                          metadata: [#file, #function, #line]))
                return
            }
            
            TranslationArchiver.addToArchive(translation)
            TranslationSerializer.uploadTranslation(translation)
            
            completion(translation, nil)
        }
    }
    
    //==================================================//
    
    /* MARK: - Speech Synthesizer Methods */
    
    private func highestQualityVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        var applicableVoices = [AVSpeechSynthesisVoice]()
        
        for voice in voices {
            guard voice.language.lowercased().hasPrefix(languageCode.lowercased()) else { continue }
            applicableVoices.append(voice)
        }
        
        var chosenVoice: AVSpeechSynthesisVoice?
        for voice in applicableVoices {
            guard voice.quality == .enhanced,
                  chosenVoice == nil else { continue }
            chosenVoice = voice
        }
        
        return chosenVoice ?? AVSpeechSynthesisVoice(language: languageCode)
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                  didCancel: AVSpeechUtterance) {
        guard let cell = selectedCell else { return }
        messagesCollectionView.reloadItems(at: [IndexPath(row: 0, section: cell.tag)])
        
        hideMenuIfVisible()
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                  didFinish: AVSpeechUtterance) {
        guard let cell = selectedCell else { return }
        messagesCollectionView.reloadItems(at: [IndexPath(row: 0, section: cell.tag)])
        
        hideMenuIfVisible()
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                  willSpeakRangeOfSpeechString characterRange: NSRange,
                                  utterance: AVSpeechUtterance) {
        guard let cell = selectedCell,
              let messageSlice = RuntimeStorage.currentMessageSlice,
              let currentUserID = RuntimeStorage.currentUserID else { return }
        
        let font = cell.messageLabel.font!
        let useWhite = messageSlice[cell.tag].fromAccountIdentifier == currentUserID
        
        let attributed = NSMutableAttributedString(string: cell.messageLabel.text!)
        attributed.addAttribute(.foregroundColor, value: useWhite ? UIColor.white : UIColor.black, range: NSMakeRange(0, attributed.length))
        attributed.addAttribute(.foregroundColor, value: UIColor.red, range: characterRange)
        attributed.addAttribute(.font, value: font, range: NSMakeRange(0, attributed.length))
        cell.messageLabel.attributedText = attributed
    }
    
    @objc private func toggleSpokenText() {
        hideMenuIfVisible()
        
        guard !speechSynthesizer.isSpeaking else {
            speechSynthesizer.stopSpeaking(at: .immediate)
            return
        }
        
        guard let cell = selectedCell,
              let messageSlice = RuntimeStorage.currentMessageSlice,
              let currentUserID = RuntimeStorage.currentUserID,
              messageSlice.count > cell.tag else { return }
        
        let message = messageSlice[cell.tag]
        let utterance = AVSpeechUtterance(string: cell.messageLabel.text!)
        let utteranceLanguage: String!
        
        if message.isDisplayingAlternate {
            if message.fromAccountIdentifier == currentUserID {
                utteranceLanguage = message.translation!.languagePair.to
            } else {
                utteranceLanguage = message.translation!.languagePair.from
            }
        } else {
            if message.fromAccountIdentifier == currentUserID {
                utteranceLanguage = message.translation!.languagePair.from
            } else {
                utteranceLanguage = message.translation!.languagePair.to
            }
        }
        
        utterance.voice = highestQualityVoice(for: utteranceLanguage)
        speechSynthesizer.speak(utterance)
    }
    
    //==================================================//
    
    /* MARK: - UICollectionView Methods */
    
    public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let messageSlice = RuntimeStorage.currentMessageSlice else { return UICollectionViewCell() }
        
        if let typingIndicatorCell = super.collectionView(collectionView, cellForItemAt: indexPath) as? TypingIndicatorCell {
            return typingIndicatorCell
        }
        
        guard let currentCell = super.collectionView(collectionView, cellForItemAt: indexPath) as? MessageCollectionViewCell else { return UICollectionViewCell() }
        currentCell.tag = indexPath.section
        
        guard messageSlice.count > indexPath.section else {
            return currentCell
        }
        
        if messageSlice[indexPath.section].isDisplayingAlternate,
           let cell = currentCell as? TextMessageCell {
            cell.messageLabel.font = cell.messageLabel.font.withTraits(traits: .traitItalic)
            
            if cell.messageContainerView.frame.size.height < 40 {
                cell.messageContainerView.frame.size.width = cell.messageLabel.intrinsicContentSize.width
                cell.messageLabel.frame.size.width = cell.messageLabel.intrinsicContentSize.width
            }
        }
        
        return currentCell
    }
    
    //==================================================//
    
    /* MARK: - UIScrollView Methods */
    
    public override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y < 0 && RuntimeStorage.isPresentingChat! {
            loadMoreMessages(fromScrollToTop: false)
        }
    }
    
    public override func scrollViewDidEndDragging(_ scrollView: UIScrollView,
                                                  willDecelerate decelerate: Bool) {
        //        print("ended dragging")
    }
    
    public override func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        loadMoreMessages(fromScrollToTop: true)
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    @objc private func copyText() {
        guard let cell = selectedCell else { return }
        UIPasteboard.general.string = cell.messageLabel.text
        
        hideMenuIfVisible()
    }
    
    @objc private func displayCustomMenu(gestureRecognizer: UIGestureRecognizer) {
        messageInputBar.tag = 86
        guard !messageInputBar.inputTextView.isFirstResponder else {
            messageInputBar.inputTextView.resignFirstResponder()
            hideMenuIfVisible()
            return
        }
        
        let point = gestureRecognizer.location(in: messagesCollectionView)
        
        guard let indexPath = messagesCollectionView.indexPathForItem(at: point),
              let cell = messagesCollectionView.cellForItem(at: indexPath) as? TextMessageCell else {
            return
        }
        
        guard (!speechSynthesizer.isSpeaking || selectedCell == cell),
              let messageSlice = RuntimeStorage.currentMessageSlice,
              let currentUserID = RuntimeStorage.currentUserID else { return }
        
        let currentMessage = messageSlice[indexPath.section]
        guard !UIMenuController.shared.isMenuVisible,
              currentMessage.identifier != "NEW" else {
            return
        }
        
        //        messageInputBar.inputTextView.resignFirstResponder()
        
        let copyItem = UIMenuItem(title: LocalizedString.copy,
                                  action: #selector(copyText))
        let speakItem = UIMenuItem(title: speechSynthesizer.isSpeaking ? LocalizedString.stopSpeaking : LocalizedString.speak,
                                   action: #selector(toggleSpokenText))
        
        //        var menuItems = [copyItem, speakItem]
        
        if currentMessage.translation!.input.value() == currentMessage.translation!.output,
           RecognitionService.shouldMarkUntranslated(currentMessage.translation!.output,
                                                     for: currentMessage.translation.languagePair) {
            let retryTranslationItem = UIMenuItem(title: LocalizedString.retryTranslation,
                                                  action: #selector(retryTranslationSelector))
            UIMenuController.shared.menuItems = [retryTranslationItem, copyItem, speakItem]
        } else {
            var menuTitle: String!
            
            if currentMessage.isDisplayingAlternate {
                menuTitle = currentMessage.fromAccountIdentifier == currentUserID ? LocalizedString.viewOriginal : LocalizedString.viewTranslation
            } else {
                menuTitle = currentMessage.fromAccountIdentifier == currentUserID ? LocalizedString.viewTranslation : LocalizedString.viewOriginal
            }
            
            let viewAlternateItem = UIMenuItem(title: menuTitle,
                                               action: #selector(viewAlternate))
            if speechSynthesizer.isSpeaking {
                UIMenuController.shared.menuItems = [copyItem, speakItem]
            } else {
                UIMenuController.shared.menuItems = [viewAlternateItem, copyItem, speakItem]
            }
        }
        
        selectedCell = cell
        
        let convertedPoint = messagesCollectionView.convert(point, to: cell.messageContainerView)
        
        if cell.messageContainerView.bounds.contains(convertedPoint) {
            messagesCollectionView.becomeFirstResponder()
            UIMenuController.shared.showMenu(from: messagesCollectionView,
                                             rect: CGRect(x: point.x,
                                                          y: (cell.frame.minY + 2) + (cell.cellTopLabel.frame.size.height),
                                                          width: 20,
                                                          height: 20))
        }
    }
    
    private func hideMenuIfVisible() {
        if UIMenuController.shared.isMenuVisible {
            UIMenuController.shared.hideMenu()
        }
    }
    
    private func indexPaths() -> [IndexPath] {
        var indexPaths = [IndexPath]()
        guard let messageSlice = RuntimeStorage.currentMessageSlice else { return indexPaths }
        
        for (index, message) in messageSlice.enumerated() {
            if message.isDisplayingAlternate {
                indexPaths.append(IndexPath(row: 0, section: index))
            }
        }
        
        return indexPaths
    }
    
    private func loadMoreMessages(fromScrollToTop: Bool) {
        guard RuntimeStorage.isPresentingChat!,
              delegatesHaveBeenSet else { return }
        
        guard let offset = RuntimeStorage.messageOffset,
              let conversation = RuntimeStorage.globalConversation,
              let messageSlice = RuntimeStorage.currentMessageSlice else { return }
        
        if abs(loadedMore.amountOfSeconds(from: Date())) > 1 || fromScrollToTop {
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
            loadedMore = Date()
        }
        
        if fromScrollToTop {
            messagesCollectionView.scrollToItem(at: IndexPath(row: 0, section: 0),
                                                at: .top,
                                                animated: true)
        }
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
        
        guard !RuntimeStorage.isSendingMessage!,
              let messageSlice = RuntimeStorage.currentMessageSlice else { return }
        
        if let indicator = RuntimeStorage.typingIndicator {
            if !messagesCollectionView.isDragging &&
                !messagesCollectionView.isTracking &&
                !messagesCollectionView.isDecelerating {
                guard isLastCellVisible || messageSlice.count <= 5 else {
                    Logger.log("Last message isn't visible, so not showing update of typing indicator.",
                               metadata: [#file, #function, #line])
                    return
                }
                
                Logger.log("Updating typing indicator status: \(indicator ? "Visible" : "Hidden")",
                           metadata: [#file, #function, #line])
                
                setTypingIndicatorViewHidden(!indicator, animated: false)
                if indicator {
                    messagesCollectionView.scrollToLastItem(animated: true)
                }
                
                RuntimeStorage.remove(.typingIndicator)
            }
        }
    }
    
    @objc private func viewAlternate() {
        hideMenuIfVisible()
        
        guard let cell = selectedCell,
              let messageSlice = RuntimeStorage.currentMessageSlice,
              messageSlice.count > cell.tag else { return }
        
        var paths = indexPaths()
        paths.append(IndexPath(row: 0, section: cell.tag))
        paths = paths.unique()
        
        let message = messageSlice[cell.tag]
        
        if let conversation = RuntimeStorage.globalConversation {
            AnalyticsService.logEvent(.viewAlternate,
                                      with: ["conversationIdKey": conversation.identifier.key!,
                                             "messageId": message.identifier!])
        }
        
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

/* MARK: Date */
public extension Date {
    func amountOfSeconds(from date: Date) -> Int {
        return Calendar.current.dateComponents([.second], from: date, to: self).second ?? 0
    }
    
    func dayOfWeek() -> String? {
        switch Calendar.current.component(.weekday, from: self) {
        case 1:
            return LocalizedString.sunday
        case 2:
            return LocalizedString.monday
        case 3:
            return LocalizedString.tuesday
        case 4:
            return LocalizedString.wednesday
        case 5:
            return LocalizedString.thursday
        case 6:
            return LocalizedString.friday
        case 7:
            return LocalizedString.saturday
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
            let separatorString = LocalizedString.today
            return messagesAttributedString("\(separatorString) \(timeString)", separationIndex: separatorString.count)
        } else if dateDifference == -86400 {
            let separatorString = LocalizedString.yesterday
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

/* MARK: InputBarAccessoryView */
extension InputBarAccessoryView {
    override open var canBecomeFirstResponder: Bool {
        return RuntimeStorage.messagesVC?.viewHasLaidOutSubviewsAtLeastOnce ?? false
    }
}

/* MARK: UIFont */
public extension UIFont {
    func bold() -> UIFont {
        return withTraits(traits: .traitBold)
    }
    
    func italic() -> UIFont {
        return withTraits(traits: .traitItalic)
    }
    
    func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return UIFont(descriptor: descriptor!, size: 0) //size 0 means keep the size as it is
    }
}

/* MARK: UITextViewDelegate */
extension ChatPageViewController: UITextViewDelegate {
    public func textViewDidBeginEditing(_ textView: UITextView) {
        messageInputBar.tag = 88
        
        Core.gcd.after(milliseconds: 250) {
            self.messagesCollectionView.scrollToLastItem(animated: true)
        }
        
        //        print(messagesCollectionView.contentInset)
        
        UIMenuController.shared.menuItems = nil
        
        guard let recipientBar = recipientBar else { return }
        recipientBar.deselectContact(animated: true)
    }
}
