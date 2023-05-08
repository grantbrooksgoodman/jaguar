//
//  MenuControllerService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 19/02/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import AVFAudio
import Foundation
import UIKit

/* Third-party Frameworks */
import InputBarAccessoryView
import MessageKit
import Translator

public typealias MenuControllerDelegate = ObjCMenuControllerDelegate & SwiftMenuControllerDelegate

@objc
public protocol ObjCMenuControllerDelegate {
    func audioMessageMenuItemAction()
    func copyMenuItemAction()
    func retryMenuItemAction()
    func speakMenuItemAction()
    func viewAlternateMenuItemAction()
}

public protocol SwiftMenuControllerDelegate {
    var messagesCollectionView: MessagesCollectionView { get }
    var messageInputBar: InputBarAccessoryView { get }
}

public class MenuControllerService: NSObject, ChatService {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // MessageContentCells
    private var selectedCell: MessageContentCell?
    private var speakingCell: MessageContentCell?
    
    // Other
    public var delegate: MenuControllerDelegate
    public var isSelectingCell: Bool { get { selectedCell != nil } }
    public var serviceType: ChatServiceType = .menuController
    public var textViewIsEmpty: Bool { get { delegate.messageInputBar.inputTextView.text.lowercasedTrimmingWhitespace == "" } }
    
    private typealias MenuController = UIMenuController
    private typealias MenuItem = UIMenuItem
    
    private let menuController = MenuController.shared
    
    private var CURRENT_USER_ID: String!
    private var CURRENT_MESSAGE_SLICE: [Message]!
    private var miscolorationTimer: Timer?
    private var speechSynthesizer: AVSpeechSynthesizer!
    private var willHideMenuNotificationName = MenuController.willHideMenuNotification
    
    //==================================================//
    
    /* MARK: - Object Lifecycle */
    
    public init(delegate: MenuControllerDelegate) throws {
        self.delegate = delegate
        super.init()
        guard syncDependencies() else { throw MenuControllerServiceError.failedToRetrieveDependencies }
        
        speechSynthesizer = AVSpeechSynthesizer()
        speechSynthesizer.delegate = self
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(menuWillHide),
                                               name: willHideMenuNotificationName,
                                               object: nil)
    }
    
    @discardableResult
    private func syncDependencies() -> Bool {
        guard let currentUserID = RuntimeStorage.currentUserID,
              let currentMessageSlice = RuntimeStorage.currentMessageSlice else { return false }
        
        CURRENT_USER_ID = currentUserID
        CURRENT_MESSAGE_SLICE = currentMessageSlice
        
        return true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self,
                                                  name: willHideMenuNotificationName,
                                                  object: nil)
        stopListeningForCellMiscoloration()
    }
    
    //==================================================//
    
    /* MARK: - Cell Miscoloration Methods */
    
    public func startListeningForCellMiscoloration() {
        miscolorationTimer = Timer.scheduledTimer(timeInterval: 0.01,
                                                  target: self,
                                                  selector: #selector(restoreMiscoloredCells),
                                                  userInfo: nil,
                                                  repeats: true)
    }
    
    public func stopListeningForCellMiscoloration() {
        miscolorationTimer?.invalidate()
        miscolorationTimer = nil
    }
    
    @objc
    private func restoreMiscoloredCells() {
        guard !menuController.isMenuVisible else { return }
        restoreCellColors()
    }
    
    //==================================================//
    
    /* MARK: - Control Methods */
    
    public func hideMenuIfNeeded() {
        guard menuController.isMenuVisible else { return }
        menuController.hideMenu()
    }
    
    public func presentMenu(at point: CGPoint,
                            on cell: MessageContentCell) {
        syncDependencies()
        
        guard cell.tag < CURRENT_MESSAGE_SLICE.count else { return }
        let currentMessage = CURRENT_MESSAGE_SLICE[cell.tag]
        
        // #warning("Bug exists where can't select speaking cell to stop it once dequeued for reuse.")
        guard currentMessage.identifier != "NEW",
              !menuController.isMenuVisible,
              (!speechSynthesizer.isSpeaking || speakingCell == cell),
              let menuItems = getMenuItems(for: cell) else { return }
        
        let convertedPoint = delegate.messagesCollectionView.convert(point, to: cell.messageContainerView)
        guard cell.messageContainerView.bounds.contains(convertedPoint) else { return }
        
        restoreCellColors()
        delegate.messagesCollectionView.becomeFirstResponder()
        animateSelection(cell.messageContainerView)
        
        let frame = CGRect(x: point.x,
                           y: (cell.frame.minY + 2) + (cell.cellTopLabel.frame.size.height),
                           width: 20,
                           height: 20)
        
        selectedCell = cell
        menuController.menuItems = menuItems
        menuController.showMenu(from: delegate.messagesCollectionView, rect: frame)
    }
    
    public func resetAllAlternates() {
        syncDependencies()
        
        for message in CURRENT_MESSAGE_SLICE where message.isDisplayingAlternate {
            let originalInput = message.translation.input
            message.translation.input = TranslationInput(message.translation.output)
            message.translation.output = originalInput.value()
            message.isDisplayingAlternate = false
        }
    }
    
    public func resetMenuItems() {
        menuController.menuItems = nil
    }
    
    public func stopSpeakingIfNeeded() {
        guard speechSynthesizer.isSpeaking else { return }
        speechSynthesizer.stopSpeaking(at: .immediate)
        speakingCell = nil
    }
    
    //==================================================//
    
    /* MARK: - Menu Actions */
    
    public func audioMessageMenuItemAction() {
        syncDependencies()
        hideMenuIfNeeded()
        
        guard let cell = selectedCell,
              CURRENT_MESSAGE_SLICE.count > cell.tag else { return }
        
        var alternateIndexPaths = alternateIndexPaths()
        alternateIndexPaths.append(IndexPath(row: 0, section: cell.tag))
        alternateIndexPaths = alternateIndexPaths.unique()
        
        let message = CURRENT_MESSAGE_SLICE[cell.tag]
        message.hasAudioComponent = message.isDisplayingAlternate ? true : false
        message.isDisplayingAlternate = message.isDisplayingAlternate ? false : true
        
        guard delegate.messagesCollectionView.visibleCells.contains(cell),
              !RuntimeStorage.isSendingMessage! else { return }
        reloadWhenSafe(alternateIndexPaths)
    }
    
    public func copyMenuItemAction() {
        guard let cell = selectedCell as? TextMessageCell else { return }
        UIPasteboard.general.string = cell.messageLabel.text
        Core.hud.flash(LocalizedString.copied, image: .success)
        
        hideMenuIfNeeded()
    }
    
    public func retryMenuItemAction() {
        guard let retranslationService = ChatServices.retranslationService,
              let cell = selectedCell else { return }
        hideMenuIfNeeded()
        retranslationService.retryTranslation(forCell: cell)
    }
    
    public func speakMenuItemAction() {
        syncDependencies()
        hideMenuIfNeeded()
        
        guard !speechSynthesizer.isSpeaking else {
            speechSynthesizer.stopSpeaking(at: .immediate)
            return
        }
        
        guard let cell = selectedCell as? TextMessageCell,
              CURRENT_MESSAGE_SLICE.count > cell.tag else { return }
        
        let message = CURRENT_MESSAGE_SLICE[cell.tag]
        let utterance = AVSpeechUtterance(string: cell.messageLabel.text!)
        let utteranceLanguage: String!
        
        let messageIsFromCurrentUser = message.fromAccountIdentifier == CURRENT_USER_ID
        let languagePair = message.translation!.languagePair
        
        if message.audioComponent != nil {
            utteranceLanguage = messageIsFromCurrentUser ? languagePair.from : languagePair.to
        } else if message.isDisplayingAlternate {
            utteranceLanguage = messageIsFromCurrentUser ? languagePair.to : languagePair.from
        } else {
            utteranceLanguage = messageIsFromCurrentUser ? languagePair.from : languagePair.to
        }
        
        AudioPlaybackController.resetAudioSession()
        
        utterance.voice = SpeechService.shared.highestQualityVoice(for: utteranceLanguage)
        speakingCell = cell
        speechSynthesizer.speak(utterance)
    }
    
    public func viewAlternateMenuItemAction() {
        syncDependencies()
        hideMenuIfNeeded()
        
        guard let cell = selectedCell,
              CURRENT_MESSAGE_SLICE.count > cell.tag else { return }
        
        var alternateIndexPaths = alternateIndexPaths()
        alternateIndexPaths.append(IndexPath(row: 0, section: cell.tag))
        alternateIndexPaths = alternateIndexPaths.unique()
        
        let message = CURRENT_MESSAGE_SLICE[cell.tag]
        
        if let conversation = RuntimeStorage.globalConversation {
            AnalyticsService.logEvent(.viewAlternate,
                                      with: ["conversationIdKey": conversation.identifier.key!,
                                             "messageId": message.identifier!])
        }
        
        let originalInput = message.translation.input
        message.translation.input = TranslationInput(message.translation.output)
        message.translation.output = originalInput.value()
        message.isDisplayingAlternate = !message.isDisplayingAlternate
        
        guard delegate.messagesCollectionView.visibleCells.contains(cell),
              !RuntimeStorage.isSendingMessage! else { return }
        reloadWhenSafe(alternateIndexPaths)
    }
    
    //==================================================//
    
    /* MARK: - Item Builders */
    
    private func getAudioMessageMenuItem(title: String? = nil) -> MenuItem {
        return .init(title: title ?? LocalizedString.viewTranscription,
                     action: #selector(delegate.audioMessageMenuItemAction))
    }
    
    private func getCopyMenuItem(title: String? = nil) -> MenuItem {
        return .init(title: title ?? LocalizedString.copy,
                     action: #selector(delegate.copyMenuItemAction))
    }
    
    private func getRetryMenuItem(title: String? = nil) -> MenuItem {
        return .init(title: title ?? LocalizedString.retryTranslation,
                     action: #selector(delegate.retryMenuItemAction))
    }
    
    private func getSpeakMenuItem(title: String? = nil) -> MenuItem {
        return .init(title: title ?? LocalizedString.speak,
                     action: #selector(delegate.speakMenuItemAction))
    }
    
    private func getViewAlternateMenuItem(title: String? = nil) -> MenuItem {
        return .init(title: title ?? LocalizedString.viewOriginal,
                     action: #selector(delegate.viewAlternateMenuItemAction))
    }
    
    //==================================================//
    
    /* MARK: - Helper Methods */
    
    private func alternateIndexPaths() -> [IndexPath] {
        syncDependencies()
        
        var indexPaths = [IndexPath]()
        for (index, message) in CURRENT_MESSAGE_SLICE.enumerated() where message.isDisplayingAlternate {
            indexPaths.append(IndexPath(row: 0, section: index))
        }
        
        return indexPaths
    }
    
    private func animateSelection(_ containerView: UIView) {
        let backgroundColor = containerView.backgroundColor
        
        guard backgroundColor?.resolvedColor(with: .current) == .senderMessageBubbleColor.resolvedColor(with: .current) || backgroundColor == .receiverMessageBubbleColor || backgroundColor == .untranslatedMessageBubbleColor else { return }
        
        UIView.animate(withDuration: 0.2) {
            guard backgroundColor == .receiverMessageBubbleColor || backgroundColor == .untranslatedMessageBubbleColor,
                  (ColorProvider.shared.interfaceStyle == .dark || ThemeService.currentTheme.style == .dark) else {
                containerView.backgroundColor = backgroundColor?.darker(by: 20)
                return
            }
            
            containerView.backgroundColor = backgroundColor?.lighter(by: 10)
        }
        
        UISelectionFeedbackGenerator().selectionChanged()
        
        return
    }
    
    private func getMenuItems(for cell: MessageContentCell) -> [MenuItem]? {
        syncDependencies()
        
        guard cell.tag < CURRENT_MESSAGE_SLICE.count else { return nil }
        
        let currentMessage = CURRENT_MESSAGE_SLICE[cell.tag]
        let translation = currentMessage.translation!
        let messageIsFromCurrentUser = currentMessage.fromAccountIdentifier == CURRENT_USER_ID
        
        guard cell as? TextMessageCell != nil else {
            guard cell as? AudioMessageCell != nil else { return nil }
            return [getAudioMessageMenuItem(title: LocalizedString.viewTranscription)]
        }
        
        var menuItems = [getCopyMenuItem()]
        
        if !AudioPlaybackController.isPlaying,
           !(!messageIsFromCurrentUser && currentMessage.audioComponent != nil) {
            let pair = translation.languagePair
            let isAlternate = currentMessage.isDisplayingAlternate
            
            if Capabilities.textToSpeechSupported(for: isAlternate ? (messageIsFromCurrentUser ? pair.to : pair.from) : (messageIsFromCurrentUser ? pair.from : pair.to)) {
                menuItems.append(getSpeakMenuItem(title: speechSynthesizer.isSpeaking ? LocalizedString.stopSpeaking : nil))
            }
        }
        
        guard currentMessage.audioComponent == nil else {
            guard !speechSynthesizer.isSpeaking else { return menuItems }
            menuItems.append(getAudioMessageMenuItem(title: LocalizedString.viewAsAudio))
            return menuItems
        }
        
        guard translation.languagePair.from != translation.languagePair.to else { return menuItems }
        
        if translation.input.value() == translation.output {
            guard RecognitionService.shouldMarkUntranslated(translation.output,
                                                            for: translation.languagePair),
                  let retranslationService = ChatServices.defaultRetranslationService,
                  !retranslationService.isRetranslating else { return menuItems }
            menuItems.append(getRetryMenuItem())
        } else {
            guard !speechSynthesizer.isSpeaking else { return menuItems }
            
            var menuTitle: String!
            switch currentMessage.isDisplayingAlternate {
            case true:
                menuTitle = messageIsFromCurrentUser ? LocalizedString.viewOriginal : LocalizedString.viewTranslation
            case false:
                menuTitle = messageIsFromCurrentUser ? LocalizedString.viewTranslation : LocalizedString.viewOriginal
            }
            
            menuItems.append(getViewAlternateMenuItem(title: menuTitle))
        }
        
        return menuItems
    }
    
    @objc
    private func menuWillHide() {
        syncDependencies()
        restoreCellColors()
        
        guard let selectedCell,
              CURRENT_MESSAGE_SLICE.count > selectedCell.tag else { return }
        
        let currentMessage = CURRENT_MESSAGE_SLICE[selectedCell.tag]
        
        UIView.animate(withDuration: 0.2) {
            selectedCell.messageContainerView.backgroundColor = currentMessage.backgroundColor
        } completion: { _ in
            Core.gcd.after(milliseconds: 200) {
                guard !self.speechSynthesizer.isSpeaking else { return }
                self.selectedCell = nil
            }
        }
    }
    
    private func reloadWhenSafe(_ indexPaths: [IndexPath]) {
        guard RuntimeStorage.isPresentingChat! else { return }
        
        guard !RuntimeStorage.isSendingMessage!,
              !RuntimeStorage.shouldReloadData! else {
            Core.gcd.after(milliseconds: 200) { self.reloadWhenSafe(indexPaths) }
            return
        }
        
        delegate.messagesCollectionView.reloadItems(at: indexPaths)
    }
    
    private func restoreCellColors() {
        syncDependencies()
        
        guard !CURRENT_MESSAGE_SLICE.isEmpty else { return }
        
        for cell in delegate.messagesCollectionView.visibleCells {
            guard let cell = cell as? MessageContentCell,
                  let indexPath = delegate.messagesCollectionView.indexPath(for: cell),
                  CURRENT_MESSAGE_SLICE.count > indexPath.section else { continue }
            
            cell.messageContainerView.backgroundColor = CURRENT_MESSAGE_SLICE[indexPath.section].backgroundColor
        }
    }
}

public enum MenuControllerServiceError: Error {
    case failedToRetrieveDependencies
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: - AVSpeechSynthesizerDelegate */
extension MenuControllerService: AVSpeechSynthesizerDelegate {
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                  didCancel: AVSpeechUtterance) {
        guard let cell = selectedCell else { return }
        
        hideMenuIfNeeded()
        speakingCell = nil
        selectedCell = nil
        
        guard delegate.messagesCollectionView.visibleCells.contains(cell),
              !RuntimeStorage.isSendingMessage! else { return }
        reloadWhenSafe([IndexPath(row: 0, section: cell.tag)])
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                  didFinish: AVSpeechUtterance) {
        guard let cell = selectedCell as? TextMessageCell,
              cell.tag < CURRENT_MESSAGE_SLICE.count else { return }
        let messageIsFromCurrentUser = CURRENT_MESSAGE_SLICE[cell.tag].fromAccountIdentifier == CURRENT_USER_ID
        let useWhite = messageIsFromCurrentUser || UITraitCollection.current.userInterfaceStyle == .dark || ThemeService.currentTheme != AppThemes.default
        cell.messageLabel.attributedText = NSAttributedString(string: cell.messageLabel.text!,
                                                              attributes: [.font: cell.messageLabel.font!,
                                                                           .foregroundColor: useWhite ? UIColor.white : UIColor.black])
        
        hideMenuIfNeeded()
        speakingCell = nil
        selectedCell = nil
        
        guard delegate.messagesCollectionView.visibleCells.contains(cell),
              !RuntimeStorage.isSendingMessage! else { return }
        reloadWhenSafe([IndexPath(row: 0, section: cell.tag)])
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                  willSpeakRangeOfSpeechString characterRange: NSRange,
                                  utterance: AVSpeechUtterance) {
        syncDependencies()
        
        guard let cell = selectedCell as? TextMessageCell,
              cell.tag < CURRENT_MESSAGE_SLICE.count else { return }
        
        guard delegate.messagesCollectionView.visibleCells.contains(cell) else { return }
        
        let font = cell.messageLabel.font!
        let messageIsFromCurrentUser = CURRENT_MESSAGE_SLICE[cell.tag].fromAccountIdentifier == CURRENT_USER_ID
        let useWhite = messageIsFromCurrentUser || UITraitCollection.current.userInterfaceStyle == .dark || ThemeService.currentTheme != AppThemes.default
        
        let attributed = NSMutableAttributedString(string: cell.messageLabel.text!)
        guard characterRange.lowerBound >= 0,
              characterRange.lowerBound < attributed.length,
              characterRange.upperBound > 0,
              characterRange.upperBound < attributed.length,
              characterRange.lowerBound < characterRange.upperBound else { return }
        
        attributed.addAttribute(.foregroundColor, value: useWhite ? UIColor.white : UIColor.black, range: NSMakeRange(0, attributed.length))
        attributed.addAttribute(.foregroundColor, value: UIColor.red, range: characterRange)
        attributed.addAttribute(.font, value: font, range: NSMakeRange(0, attributed.length))
        
        cell.messageLabel.attributedText = attributed
    }
}

/* MARK: - ChatPageViewController */
extension ChatPageViewController {
    
    //==================================================//
    
    /* MARK: - Menu Item Overrides */
    
    public override func canPerformAction(_ action: Selector,
                                          withSender sender: Any?) -> Bool {
        let actions = [#selector(ChatPageViewController.audioMessageMenuItemAction),
                       #selector(ChatPageViewController.copyMenuItemAction),
                       #selector(ChatPageViewController.retryMenuItemAction),
                       #selector(ChatPageViewController.speakMenuItemAction),
                       #selector(ChatPageViewController.viewAlternateMenuItemAction)]
        return actions.contains(action)
    }
    
    //==================================================//
    
    /* MARK: - Menu Item Actions */
    
    @objc
    public func audioMessageMenuItemAction() {
        ChatServices.menuControllerService?.audioMessageMenuItemAction()
    }
    
    @objc
    public func copyMenuItemAction() {
        ChatServices.menuControllerService?.copyMenuItemAction()
    }
    
    @objc
    public func retryMenuItemAction() {
        ChatServices.menuControllerService?.retryMenuItemAction()
    }
    
    @objc
    public func speakMenuItemAction() {
        ChatServices.menuControllerService?.speakMenuItemAction()
    }
    
    @objc
    public func viewAlternateMenuItemAction() {
        ChatServices.menuControllerService?.viewAlternateMenuItemAction()
    }
}

/* MARK: InputTextView */
extension InputTextView {
    
    //==================================================//
    
    /* MARK: - Menu Item Overrides */
    
    public override func canPerformAction(_ action: Selector,
                                          withSender sender: Any?) -> Bool {
        let messageBubbleActions = [#selector(ChatPageViewController.audioMessageMenuItemAction),
                                    #selector(ChatPageViewController.copyMenuItemAction),
                                    #selector(ChatPageViewController.retryMenuItemAction),
                                    #selector(ChatPageViewController.speakMenuItemAction),
                                    #selector(ChatPageViewController.viewAlternateMenuItemAction)]
        
        let textViewActions = [#selector(cut(_:)),
                               #selector(copy(_:)),
                               #selector(paste(_:)),
                               #selector(selectAll(_:))]
        
        guard let menuService = ChatServices.defaultMenuControllerService else { return false }
        menuService.resetMenuItems()
        
        guard menuService.isSelectingCell else {
            guard menuService.textViewIsEmpty else {
                return textViewActions.contains(action)
            }
            
            return action == #selector(paste(_:))
        }
        
        return messageBubbleActions.contains(action)
    }
    
    //==================================================//
    
    /* MARK: - Menu Item Actions */
    
    @objc
    public func audioMessageMenuItemAction() {
        ChatServices.defaultMenuControllerService?.audioMessageMenuItemAction()
    }
    
    @objc
    public func copyMenuItemAction() {
        ChatServices.defaultMenuControllerService?.copyMenuItemAction()
    }
    
    @objc
    public func retryMenuItemAction() {
        ChatServices.defaultMenuControllerService?.retryMenuItemAction()
    }
    
    @objc
    public func speakMenuItemAction() {
        ChatServices.defaultMenuControllerService?.speakMenuItemAction()
    }
    
    @objc
    public func viewAlternateMenuItemAction() {
        ChatServices.defaultMenuControllerService?.viewAlternateMenuItemAction()
    }
}
