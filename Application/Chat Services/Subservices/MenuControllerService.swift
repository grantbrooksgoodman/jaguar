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
}

public class MenuControllerService: NSObject, ChatService {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public var delegate: MenuControllerDelegate
    public var serviceType: ChatServiceType = .menuController
    
    private let menuController = UIMenuController.shared
    
    private var CURRENT_USER_ID: String!
    private var CURRENT_MESSAGE_SLICE: [Message]!
    private var selectedCell: MessageContentCell?
    private var speechSynthesizer: AVSpeechSynthesizer!
    
    //==================================================//
    
    /* MARK: - Constructor & Initialization Methods */
    
    public init(delegate: MenuControllerDelegate) throws {
        self.delegate = delegate
        super.init()
        guard syncDependencies() else { throw MenuControllerServiceError.failedToRetrieveDependencies }
        
        speechSynthesizer = AVSpeechSynthesizer()
        speechSynthesizer.delegate = self
    }
    
    @discardableResult
    private func syncDependencies() -> Bool {
        guard let currentUserID = RuntimeStorage.currentUserID,
              let currentMessageSlice = RuntimeStorage.currentMessageSlice else { return false }
        
        CURRENT_USER_ID = currentUserID
        CURRENT_MESSAGE_SLICE = currentMessageSlice
        
        return true
    }
    
    //==================================================//
    
    /* MARK: - Control Methods */
    
    public func hideMenuIfNeeded() {
        guard menuController.isMenuVisible else { return }
        menuController.hideMenu()
    }
    
    public func presentMenu(at point: CGPoint,
                            on cell: MessageContentCell) {
        guard (!speechSynthesizer.isSpeaking || selectedCell == cell),
              let menuItems = getMenuItems(for: cell) else { return }
        
        let convertedPoint = delegate.messagesCollectionView.convert(point,
                                                                     to: cell.messageContainerView)
        guard cell.messageContainerView.bounds.contains(convertedPoint) else { return }
        
        delegate.messagesCollectionView.becomeFirstResponder()
        
        let frame = CGRect(x: point.x,
                           y: (cell.frame.minY + 2) + (cell.cellTopLabel.frame.size.height),
                           width: 20,
                           height: 20)
        
        selectedCell = cell
        menuController.menuItems = menuItems
        menuController.showMenu(from: delegate.messagesCollectionView, rect: frame)
    }
    
    public func stopSpeakingIfNeeded() {
        guard speechSynthesizer.isSpeaking else { return }
        speechSynthesizer.stopSpeaking(at: .immediate)
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
        
        delegate.messagesCollectionView.reloadItems(at: alternateIndexPaths)
        selectedCell = nil
    }
    
    public func copyMenuItemAction() {
        guard let cell = selectedCell as? TextMessageCell else { return }
        UIPasteboard.general.string = cell.messageLabel.text
        
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
        
        if message.isDisplayingAlternate {
            utteranceLanguage = messageIsFromCurrentUser ? languagePair.to : languagePair.from
        } else {
            utteranceLanguage = messageIsFromCurrentUser ? languagePair.from : languagePair.to
        }
        
        utterance.voice = SpeechService.shared.highestQualityVoice(for: utteranceLanguage)
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
        
        delegate.messagesCollectionView.reloadItems(at: alternateIndexPaths)
        selectedCell = nil
    }
    
    //==================================================//
    
    /* MARK: - Item Builders */
    
    private func getAudioMessageMenuItem(title: String? = nil) -> UIMenuItem {
        return .init(title: title ?? LocalizedString.viewOriginal,
                     action: #selector(delegate.audioMessageMenuItemAction))
    }
    
    private func getCopyMenuItem(title: String? = nil) -> UIMenuItem {
        return .init(title: title ?? LocalizedString.copy,
                     action: #selector(delegate.copyMenuItemAction))
    }
    
    private func getRetryMenuItem(title: String? = nil) -> UIMenuItem {
        return .init(title: title ?? LocalizedString.retryTranslation,
                     action: #selector(delegate.retryMenuItemAction))
    }
    
    private func getSpeakMenuItem(title: String? = nil) -> UIMenuItem {
        return .init(title: title ?? LocalizedString.speak,
                     action: #selector(delegate.speakMenuItemAction))
    }
    
    private func getViewAlternateMenuItem(title: String? = nil) -> UIMenuItem {
        return .init(title: title ?? LocalizedString.viewOriginal,
                     action: #selector(ChatPageViewController.viewAlternateMenuItemAction))
    }
    
    //==================================================//
    
    /* MARK: - Helper Methods */
    
    private func alternateIndexPaths() -> [IndexPath] {
        syncDependencies()
        
        var indexPaths = [IndexPath]()
        for (index, message) in CURRENT_MESSAGE_SLICE.enumerated() {
            guard message.isDisplayingAlternate else { continue }
            indexPaths.append(IndexPath(row: 0, section: index))
        }
        
        return indexPaths
    }
    
    private func getMenuItems(for cell: MessageContentCell) -> [UIMenuItem]? {
        syncDependencies()
        
        guard cell.tag < CURRENT_MESSAGE_SLICE.count else { return nil }
        
        let currentMessage = CURRENT_MESSAGE_SLICE[cell.tag]
        let translation = currentMessage.translation!
        
        guard cell as? TextMessageCell != nil else {
            guard cell as? AudioMessageCell != nil else { return nil }
            return [getAudioMessageMenuItem(title: LocalizedString.viewTranscription)]
        }
        
        var menuItems = [getCopyMenuItem()]
        
        guard currentMessage.audioComponent == nil else {
            menuItems.append(getAudioMessageMenuItem(title: LocalizedString.viewAsAudio))
            return menuItems
        }
        
        menuItems.append(getSpeakMenuItem(title: speechSynthesizer.isSpeaking ? LocalizedString.stopSpeaking : nil))
        
        if translation.input.value() == translation.output,
           RecognitionService.shouldMarkUntranslated(translation.output,
                                                     for: translation.languagePair) {
            menuItems.append(getRetryMenuItem())
        } else {
            guard !speechSynthesizer.isSpeaking else { return menuItems }
            
            let messageIsFromCurrentUser = currentMessage.fromAccountIdentifier == CURRENT_USER_ID
            
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
        delegate.messagesCollectionView.reloadItems(at: [IndexPath(row: 0, section: cell.tag)])
        
        hideMenuIfNeeded()
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                  didFinish: AVSpeechUtterance) {
        guard let cell = selectedCell else { return }
        delegate.messagesCollectionView.reloadItems(at: [IndexPath(row: 0, section: cell.tag)])
        
        hideMenuIfNeeded()
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                  willSpeakRangeOfSpeechString characterRange: NSRange,
                                  utterance: AVSpeechUtterance) {
        syncDependencies()
        
        guard let cell = selectedCell as? TextMessageCell,
              cell.tag < CURRENT_MESSAGE_SLICE.count else { return }
        
        let font = cell.messageLabel.font!
        let useWhite = CURRENT_MESSAGE_SLICE[cell.tag].fromAccountIdentifier == CURRENT_USER_ID
        
        let attributed = NSMutableAttributedString(string: cell.messageLabel.text!)
        attributed.addAttribute(.foregroundColor, value: useWhite ? UIColor.white : UIColor.black, range: NSMakeRange(0, attributed.length))
        attributed.addAttribute(.foregroundColor, value: UIColor.red, range: characterRange)
        attributed.addAttribute(.font, value: font, range: NSMakeRange(0, attributed.length))
        cell.messageLabel.attributedText = attributed
    }
}

/* MARK: - ChatPageViewController */
extension ChatPageViewController {
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
