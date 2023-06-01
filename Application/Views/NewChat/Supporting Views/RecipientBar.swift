//
//  RecipientBar.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/11/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Contacts
import SwiftUI
import UIKit

/* Third-party Frameworks */
import AlertKit

public class RecipientBar: UIView {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Arrays
    private let contactPairs: [ContactPair]!
    
    private var queriedContactPairs = [ContactPair]()
    private var tableViewSections = [TableViewSection]()
    
    // UITapGestureRecognizers
    private var deselectContactGesture: UITapGestureRecognizer!
    private var toggleContactSelectedGesture: UITapGestureRecognizer!
    
    // Other
    public let delegate: ChatPageViewController!
    public var selectedContactPair: ContactPair? {
        didSet {
            delegate.messageInputBar.sendButton.isEnabled = RuntimeStorage.coordinator?.shouldEnableSendButton ?? true
        }
    }
    
    private var contactTableView: UITableView!
    private var isAnimating = false
    private var recipientBarBorderColor: CGColor {
        let darkModeBorderColor = UIColor(hex: 0x3C3C434A).cgColor
        guard ThemeService.currentTheme == AppThemes.default else { return darkModeBorderColor }
        return delegate.traitCollection.userInterfaceStyle == .dark ? darkModeBorderColor : UIColor(hex: 0xDCDCDD).cgColor
    }
    
    private struct TableViewSection {
        let letter: String
        let contactPairs: [ContactPair]
    }
    
    //==================================================//
    
    /* MARK: - Constructors */
    
    public init(delegate: ChatPageViewController,
                contactPairs: [ContactPair]) {
        self.delegate = delegate
        self.contactPairs = contactPairs
        
        super.init(frame: CGRect(x: 0,
                                 y: 0,
                                 width: UIScreen.main.bounds.width,
                                 height: 54))
        
        addVerticalBorders(color: recipientBarBorderColor,
                           height: 0.3)
        
        backgroundColor = UIColor.white.withAlphaComponent(0.98)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //==================================================//
    
    /* MARK: - Overridden Methods */
    
    public override func layoutSubviews() {
        if delegate.view.subviews.filter({ $0 is UITableView }).count == 0/*,
                                                                           !contactPairs.isEmpty*/ {
            contactTableView = getContactTableView()
            delegate.view.addSubview(contactTableView)
            
            reloadTableView()
        }
        
        if subviews(for: "toLabel").isEmpty {
            let toLabel = getToLabel()
            toLabel.tag = Core.ui.nameTag(for: "toLabel")
            addSubview(toLabel)
        }
        
        if subviews(for: "recipientTextField").isEmpty {
            guard selectedContactPair == nil else { return }
            let recipientTextField = getRecipientTextField()
            recipientTextField.tag = Core.ui.nameTag(for: "recipientTextField")
            addSubview(recipientTextField)
            
            Core.gcd.after(milliseconds: 650) {
                recipientTextField.becomeFirstResponder()
            }
        }
        
        if subviews(for: "selectContactButton").isEmpty {
            let selectContactButton = getSelectContactButton()
            selectContactButton.tag = Core.ui.nameTag(for: "selectContactButton")
            addSubview(selectContactButton)
            
            Core.gcd.after(milliseconds: 800) {
                guard !self.isAnimating else { return }
                selectContactButton.isEnabled = true
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Contact Selection Handler */
    
    private func displayExistingChat(with userID: String) {
        if let openConversations = RuntimeStorage.currentUser!.openConversations,
           let conversation = openConversations.filter({ $0.participants.userIDs.contains(userID) }).first {
            if let coordinator = RuntimeStorage.coordinator {
                coordinator.setConversation(conversation)
                delegate.messagesCollectionView.reloadData()
            }
            
            guard let otherUser = conversation.otherUser else { return }
            reconfigureInputBar(nil, otherUser)
        }
    }
    
    public func handleContactSelected(with contactPair: ContactPair) {
        func showChat(with userID: String,
                      contactPair: ContactPair) {
            displayExistingChat(with: userID)
            delegate.messagesCollectionView.isUserInteractionEnabled = true
            
            selectedContactPair = contactPair
            showSelectedContact(name: "\(contactPair.contact.firstName) \(contactPair.contact.lastName)",
                                scrollsToBottom: true)
        }
        
        func resetChat() {
            if let coordinator = RuntimeStorage.coordinator {
                coordinator.setConversation(Conversation.empty())
                self.delegate.messagesCollectionView.reloadData()
            }
            
            reconfigureInputBar(contactPair)
        }
        
        ContactNavigationRouter.routeNavigation(with: contactPair) { selectedUser, exception in
            guard let selectedUser else {
                guard let exception else {
                    resetChat()
                    Logger.log(Exception(metadata: [#file, #function, #line]), with: .errorAlert)
                    return
                }
                
                if exception.isEqual(to: .conversationAlreadyExists),
                   let userID = exception.extraParams?["UserID"] as? String {
                    showChat(with: userID, contactPair: contactPair)
                } else {
                    resetChat()
                    Logger.log(exception, with: .errorAlert)
                }
                
                return
            }
            
            guard RuntimeStorage.currentUser?.openConversations?.filter({ $0.participants.userIDs.contains(selectedUser.identifier) }).first == nil else {
                showChat(with: selectedUser.identifier, contactPair: contactPair)
                return
            }
            
            resetChat()
            self.selectedContactPair = contactPair
            self.showSelectedContact(name: "\(contactPair.contact.firstName) \(contactPair.contact.lastName)")
        }
    }
    
    private func handleNumberEntered(_ phoneNumber: String) {
        func showChat(with userID: String,
                      cellTitle: String) {
            displayExistingChat(with: userID)
            delegate.messagesCollectionView.isUserInteractionEnabled = true
            
            let phoneNumber = PhoneNumber(digits: phoneNumber.digits,
                                          rawStringHasPlusPrefix: true)
            let contact = Contact(firstName: "",
                                  lastName: "",
                                  phoneNumbers: [phoneNumber])
            
            selectedContactPair = ContactPair(contact: contact,
                                              numberPairs: nil)
            showSelectedContact(name: cellTitle, scrollsToBottom: true)
        }
        
        func resetChat() {
            if let coordinator = RuntimeStorage.coordinator {
                coordinator.setConversation(Conversation.empty())
                self.delegate.messagesCollectionView.reloadData()
            }
        }
        
        ContactNavigationRouter.routeNavigation(with: phoneNumber) { selectedUser, exception in
            guard let selectedUser else {
                guard let exception else {
                    resetChat()
                    Logger.log(Exception(metadata: [#file, #function, #line]), with: .errorAlert)
                    return
                }
                
                if exception.isEqual(to: .conversationAlreadyExists),
                   let userID = exception.extraParams?["UserID"] as? String,
                   let cellTitle = exception.extraParams?["CellTitle"] as? String {
                    showChat(with: userID, cellTitle: cellTitle)
                } else if exception.isEqual(to: .noUserWithHashes) ||
                            exception.isEqual(to: .noUserWithPhoneNumber) ||
                            exception.isEqual(to: .mismatchedHashAndCallingCode) ||
                            exception.isEqual(to: .noCallingCodesForNumber) ||
                            exception.isEqual(to: .noHashesForNumber),
                          let textField = self.subview(for: "recipientTextField") as? UITextField {
                    self.selectedContactPair = ContactPair(contact: Contact.empty(), numberPairs: nil)
                    self.showSelectedContact(name: textField.text!)
                } else {
                    resetChat()
                    Logger.log(exception, with: .errorAlert)
                }
                
                return
            }
            
            self.reconfigureInputBar(nil, selectedUser)
            
            guard RuntimeStorage.currentUser?.openConversations?.filter({ $0.participants.userIDs.contains(selectedUser.identifier) }).first == nil else {
                showChat(with: selectedUser.identifier, cellTitle: selectedUser.cellTitle)
                return
            }
            
            let phoneNumber = PhoneNumber(digits: selectedUser.phoneNumber,
                                          rawStringHasPlusPrefix: true)
            let contact = Contact(firstName: selectedUser.cellTitle,
                                  lastName: "",
                                  phoneNumbers: [phoneNumber])
            
            self.selectedContactPair = ContactPair(contact: contact,
                                                   numberPairs: [NumberPair(number: selectedUser.phoneNumber,
                                                                            users: [selectedUser])])
            self.showSelectedContact(name: selectedUser.cellTitle)
        }
    }
    
    private func showSelectedContact(name: String,
                                     scrollsToBottom: Bool? = nil) {
        let scrollsToBottom = scrollsToBottom ?? false
        
        removeSubview(Core.ui.nameTag(for: "recipientTextField"), animated: false)
        
        hideTableView()
        
        let useRedColor = selectedContactPair?.isEmpty ?? false
        
        let contactLabel = getContactLabel(name,
                                           useRedColor: useRedColor)
        contactLabel.tag = Core.ui.nameTag(for: "contactLabel")
        
        let contactEnclosingView = getContactEnclosingView()
        contactEnclosingView.addSubview(contactLabel)
        
        contactEnclosingView.tag = Core.ui.nameTag(for: "contactEnclosingView")
        
        contactEnclosingView.frame.size.width = contactLabel.frame.size.width + 10
        addSubview(contactEnclosingView)
        
        contactLabel.center = CGPoint(x: contactLabel.superview!.bounds.midX,
                                      y: contactLabel.superview!.bounds.midY)
        
        let inputBar = delegate.messageInputBar
        inputBar.sendButton.isEnabled = (RuntimeStorage.coordinator?.shouldEnableSendButton ?? true) && !useRedColor
        
        if scrollsToBottom {
            Core.gcd.after(milliseconds: 150) {
                self.delegate.messagesCollectionView.scrollToLastItem()
            }
        }
        
        Core.gcd.after(milliseconds: scrollsToBottom ? 750 : 100) {
            if !useRedColor {
                inputBar.inputTextView.placeholder = " \(LocalizedString.newMessage)"
#if !EXTENSION
                guard let topViewController = UIApplication.topViewController(),
                      !topViewController.isKind(of: UIAlertController.self) else { return }
#endif
                inputBar.inputTextView.becomeFirstResponder()
            }
        }
        
        if useRedColor,
           let selectContactButton = subview(for: "selectContactButton") as? UIButton {
            selectContactButton.alpha = 0
            toggleContactSelected()
        }
        
        deselectContactGesture = UITapGestureRecognizer(target: self,
                                                        action: #selector(deselectContact(animated:)))
        superview!.addGestureRecognizer(deselectContactGesture)
        
        toggleContactSelectedGesture = UITapGestureRecognizer(target: self,
                                                              action: #selector(toggleContactSelected))
        addGestureRecognizer(toggleContactSelectedGesture)
    }
    
    //==================================================//
    
    /* MARK: - Button Action Selectors */
    
    @objc private func clearButtonAction() {
        selectedContactPair = nil
        ContactNavigationRouter.currentlySelectedUser = nil
        
        guard let recognizer = toggleContactSelectedGesture else { return }
        removeGestureRecognizer(recognizer)
        
        removeSubview(Core.ui.nameTag(for: "contactLabel"), animated: false)
        removeSubview(Core.ui.nameTag(for: "contactEnclosingView"), animated: false)
        removeSubview(Core.ui.nameTag(for: "clearButton"), animated: false)
        
        let recipientTextField = getRecipientTextField()
        recipientTextField.tag = Core.ui.nameTag(for: "recipientTextField")
        addSubview(recipientTextField)
        
        recipientTextField.becomeFirstResponder()
        
        reloadTableView()
        delegate.messageInputBar.inputTextView.placeholder = nil
        
        if let coordinator = RuntimeStorage.coordinator {
            coordinator.setConversation(Conversation.empty())
            delegate.messagesCollectionView.reloadData()
        }
        
        delegate.messageInputBar.sendButton.isEnabled = (RuntimeStorage.coordinator?.shouldEnableSendButton ?? false)
        reconfigureInputBar()
        
        guard subviews(for: "selectContactButton").isEmpty else {
            if let button = subview(for: "selectContactButton") as? UIButton {
                button.alpha = 1
            }
            
            return
        }
        
        Logger.log("Adding subview for «selectContactButton». (Shouldn't be!)",
                   with: .normalAlert,
                   metadata: [#file, #function, #line])
        
        let selectContactButton = getSelectContactButton()
        selectContactButton.tag = Core.ui.nameTag(for: "selectContactButton")
        selectContactButton.isEnabled = true
        addSubview(selectContactButton)
    }
    
    @objc public func selectContactButtonAction() {
        guard PermissionService.contactPermissionStatus == .granted else {
            guard PermissionService.contactPermissionStatus == .unknown else {
                PermissionService.presentCTA(for: .contacts) { }
                return
            }
            
            StateProvider.shared.tappedDone = true
            Core.gcd.after(seconds: 1) {
                PermissionService.requestPermission(for: .contacts) { status, exception in
                    guard status == .granted else {
                        guard let exception else {
                            PermissionService.presentCTA(for: .contacts) { }
                            return
                        }
                        
                        Logger.log(exception, with: .errorAlert)
                        return
                    }
                    
                    if let archivedHashes = UserDefaults.standard.value(forKey: UserDefaultsKeys.archivedLocalUserHashesKey) as? [String] {
                        RuntimeStorage.store(archivedHashes, as: .archivedLocalUserHashes)
                        StateProvider.shared.showNewChatPageForGrantedContactAccess = true
                    } else {
                        ContactService.getLocalUserHashes { hashes, exception in
                            guard let hashes else {
                                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]))
                                return
                            }
                            
                            UserDefaults.standard.set(hashes, forKey: UserDefaultsKeys.archivedLocalUserHashesKey)
                            RuntimeStorage.store(hashes, as: .archivedLocalUserHashes)
                            StateProvider.shared.showNewChatPageForGrantedContactAccess = true
                        }
                    }
                }
            }
            
            return
        }
        
        guard !contactPairs.excludingCurrentUser.isEmpty else {
            promptToInvite()
            return
        }
        
        StateProvider.shared.tappedSelectContactButton = true
        delegate.messageInputBar.inputTextView.resignFirstResponder()
        if let recipientTextField = subview(for: "recipientTextField") as? UITextField {
            recipientTextField.resignFirstResponder()
        }
    }
    
    //==================================================//
    
    /* MARK: - Gesture Recognizer Selectors */
    
    @objc public func deselectContact(animated: Bool) {
        removeSubview(Core.ui.nameTag(for: "clearButton"), animated: false)
        
        guard let contactEnclosingView = subview(for: "contactEnclosingView"),
              let contactLabel = contactEnclosingView.subview(Core.ui.nameTag(for: "contactLabel")) as? UILabel else { return }
        
        guard contactEnclosingView.backgroundColor != .clear else { return }
        
        contactLabel.textColor = (selectedContactPair?.isEmpty ?? false) ? .systemRed : .primaryAccentColor
        let selectionColor = UIColor(hex: delegate.traitCollection.userInterfaceStyle == .dark ? 0x2A2A2C : 0xECF0F1)
        contactEnclosingView.backgroundColor = selectionColor
        contactEnclosingView.layer.borderColor = selectionColor.cgColor
        
        guard animated,
              let selectContactButton = subview(for: "selectContactButton") as? UIButton else { return }
        
        isAnimating = true
        UIView.animate(withDuration: 0.3,
                       delay: 0.5,
                       options: []) {
            contactEnclosingView.backgroundColor = .clear
            contactEnclosingView.layer.borderColor = UIColor.clear.cgColor
            selectContactButton.alpha = 0
        } completion: { _ in
            self.isAnimating = false
        }
    }
    
    @objc private func toggleContactSelected() {
        guard !isAnimating else { return }
        
        guard let contactEnclosingView = subview(for: "contactEnclosingView"),
              let contactLabel = contactEnclosingView.subview(Core.ui.nameTag(for: "contactLabel")) as? UILabel else {
            Logger.log(Exception("Couldn't unwrap subviews.", metadata: [#file, #function, #line]))
            return
        }
        
        let useRedColor = selectedContactPair?.isEmpty ?? false
        let currentlySelected = contactLabel.textColor == .white
        
        if currentlySelected {
            contactLabel.textColor = useRedColor ? .systemRed : .primaryAccentColor
            let selectionColor = UIColor(hex: delegate.traitCollection.userInterfaceStyle == .dark ? 0x2A2A2C : 0xECF0F1)
            contactEnclosingView.backgroundColor = selectionColor
            contactEnclosingView.layer.borderColor = selectionColor.cgColor
            
            removeSubview(Core.ui.nameTag(for: "clearButton"), animated: false)
        } else {
            if let clearButton = getClearButton() {
                clearButton.tag = Core.ui.nameTag(for: "clearButton")
                addSubview(clearButton)
            }
            
            contactLabel.textColor = .white
            contactEnclosingView.backgroundColor = useRedColor ? .systemRed : .primaryAccentColor
            contactEnclosingView.layer.borderColor = useRedColor ? UIColor.systemRed.cgColor : UIColor.primaryAccentColor.cgColor
            
            delegate.messageInputBar.inputTextView.resignFirstResponder()
        }
    }
    
    //==================================================//
    
    /* MARK: - Table View Methods */
    
    private func getTableViewSections() -> [TableViewSection] {
        let groupedDictionary = Dictionary(grouping: queriedContactPairs,
                                           by: { String($0.contact.lastName.prefix(1)) })
        let keys = groupedDictionary.keys.sorted()
        return keys.map { TableViewSection(letter: $0,
                                           contactPairs: groupedDictionary[$0]!.sorted(by: { $0.contact.lastName < $1.contact.lastName })) }
    }
    
    private func hideTableView() {
        queriedContactPairs = contactPairs
        tableViewSections = getTableViewSections()
        
        contactTableView.alpha = 0
        contactTableView.reloadData()
        
        delegate.messageInputBar.isHidden = false
        //        delegate.messagesCollectionView.isUserInteractionEnabled = true
    }
    
    private func reloadTableView() {
        func reset() {
            queriedContactPairs = contactPairs
            tableViewSections = getTableViewSections()
            
            contactTableView.reloadData()
            delegate.messagesCollectionView.isUserInteractionEnabled = false
            
            guard let recognizer = deselectContactGesture else { return }
            superview!.removeGestureRecognizer(recognizer)
        }
        
        guard !contactPairs.isEmpty else { /*fatalError("Empty «contactPairs»!")*/ return }
        
        contactTableView.dataSource = self
        contactTableView.delegate = self
        reset()
    }
    
    //==================================================//
    
    /* MARK: - Text Field Selector */
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        guard selectedContactPair == nil,
              textField.text != nil && textField.text?.lowercasedTrimmingWhitespace != "" else {
            hideTableView()
            return
        }
        
        queriedContactPairs = contactPairs.filter({ "\($0.contact!)".lowercased().contains(textField.text!.lowercased()) })
        tableViewSections = getTableViewSections()
        
        contactTableView.reloadData()
        contactTableView.alpha = 1
        
        delegate.messageInputBar.isHidden = true
        
        let range = textField.text!.rangeOfCharacter(from: CharacterSet.letters)
        guard range == nil else { return }
        
        textField.text = PhoneNumberService.format(textField.text!, useFailsafe: false)
    }
    
    //==================================================//
    
    /* MARK: - View Builders */
    
    private func getClearButton() -> UIButton? {
        guard let contactEnclosingView = subview(for: "contactEnclosingView") else {
            Logger.log(Exception("Couldn't unwrap subviews.", metadata: [#file, #function, #line]))
            return nil
        }
        
        let clearButton = UIButton(frame: CGRect(x: 0,
                                                 y: 0,
                                                 width: 23,
                                                 height: 23))
        
        clearButton.addTarget(self, action: #selector(clearButtonAction), for: .touchUpInside)
        clearButton.setImage(UIImage(systemName: "x.circle.fill"), for: .normal)
        clearButton.tintColor = .lightGray
        
        clearButton.frame.origin.x = (contactEnclosingView.frame.maxX + clearButton.intrinsicContentSize.width) - 18
        clearButton.center.y = center.y
        
        return clearButton
    }
    
    private func getContactEnclosingView() -> UIView {
        /*guard*/ let toLabel = subview(for: "toLabel") as! UILabel /*else {
                                                                     Logger.log(Exception("Couldn't unwrap subviews.",
                                                                     metadata: [#file, #function, #line]))
                                                                     return
                                                                     }*/
        
        let contactEnclosingView = UIView(frame: CGRect(x: 40,
                                                        y: 0,
                                                        width: 0,
                                                        height: 30))
        
        let selectionColor = UIColor(hex: delegate.traitCollection.userInterfaceStyle == .dark ? 0x2A2A2C : 0xECF0F1)
        
        contactEnclosingView.backgroundColor = selectionColor
        contactEnclosingView.center.y = center.y
        contactEnclosingView.isUserInteractionEnabled = true
        
        contactEnclosingView.layer.borderColor = selectionColor.cgColor
        contactEnclosingView.layer.borderWidth = 1
        contactEnclosingView.layer.cornerRadius = 10
        
        contactEnclosingView.frame.origin.x = toLabel.frame.maxX + 5
        
        return contactEnclosingView
    }
    
    private func getContactLabel(_ text: String,
                                 useRedColor: Bool? = nil) -> UILabel {
        let contactLabel = UILabel()
        let useRedColor = useRedColor ?? false
        
        contactLabel.text = text
        contactLabel.textAlignment = .center
        contactLabel.textColor = useRedColor ? .systemRed : .primaryAccentColor
        
        contactLabel.frame.size.height = contactLabel.intrinsicContentSize.height
        contactLabel.frame.size.width = contactLabel.intrinsicContentSize.width
        
        return contactLabel
    }
    
    private func getContactTableView() -> UITableView {
        let contactTableView = UITableView(frame: delegate.messagesCollectionView.superview!.frame)
        
        contactTableView.alpha = 0
        contactTableView.frame.origin.y += 54
        contactTableView.register(ContactCell.self, forCellReuseIdentifier: "contactCell")
        
        return contactTableView
    }
    
    private func getRecipientTextField() -> UITextField {
        /*guard*/ let toLabel = subview(for: "toLabel") as! UILabel /*else {
                                                                     Logger.log(Exception("Couldn't unwrap subviews.",
                                                                     metadata: [#file, #function, #line]))
                                                                     return
                                                                     }*/
        
        let recipientTextField = UITextField(frame: CGRect(x: 0,
                                                           y: 0,
                                                           width: UIScreen.main.bounds.width - 85,
                                                           height: 54))
        
        recipientTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        recipientTextField.delegate = self
        
        recipientTextField.center.x = center.x
        recipientTextField.frame.origin.x = toLabel.frame.maxX + 5
        
        recipientTextField.autocorrectionType = .no
        recipientTextField.keyboardType = .namePhonePad
        recipientTextField.spellCheckingType = .no
        
        return recipientTextField
    }
    
    private func getSelectContactButton() -> UIButton {
        let selectContactButton = UIButton(type: .contactAdd)
        selectContactButton.tintColor = .primaryAccentColor
        
        selectContactButton.addTarget(self, action: #selector(selectContactButtonAction), for: .touchUpInside)
        selectContactButton.isEnabled = false
        
        selectContactButton.frame.size.height = selectContactButton.intrinsicContentSize.height
        selectContactButton.frame.size.width = selectContactButton.intrinsicContentSize.width
        
        selectContactButton.frame.origin.x = (frame.maxX - selectContactButton.intrinsicContentSize.width) - 10
        selectContactButton.center.y = center.y
        
        return selectContactButton
    }
    
    private func getToLabel() -> UILabel {
        let toLabel = UILabel(frame: CGRect(x: 15,
                                            y: 0,
                                            width: 0,
                                            height: 54))
        
        toLabel.font = UIFont(name: "SFUIText-Regular", size: 14)
        toLabel.text = LocalizedString.to
        toLabel.textColor = .gray
        
        toLabel.frame.size.width = toLabel.intrinsicContentSize.width
        toLabel.center.y = center.y
        
        return toLabel
    }
    
    //==================================================//
    
    /* MARK: - Input Bar Configuration */
    
    private func reconfigureInputBar(_ pair: ContactPair? = nil,
                                     _ user: User? = nil) {
        guard let currentUser = RuntimeStorage.currentUser,
              currentUser.canSendAudioMessages else {
            ChatServices.defaultChatUIService?.configureInputBar(forRecord: !RuntimeStorage.acknowledgedAudioMessagesUnsupported!)
            return
        }
        
        var selectedUser: User? {
            guard let selectedContactPair,
                  let numberPairs = selectedContactPair.numberPairs,
                  let user = numberPairs.first(where: { !$0.users.isEmpty })?.users.first else { return nil }
            return user
        }
        
        var shouldEnableRecording = false
        
        if let pair,
           let numberPairs = pair.numberPairs,
           let user = numberPairs.first(where: { !$0.users.isEmpty })?.users.first {
            shouldEnableRecording = Capabilities.textToSpeechSupported(for: user.languageCode)
        } else if let user {
            shouldEnableRecording = Capabilities.textToSpeechSupported(for: user.languageCode)
        } else if let selectedUser {
            shouldEnableRecording = Capabilities.textToSpeechSupported(for: selectedUser.languageCode)
        } else {
            shouldEnableRecording = currentUser.canSendAudioMessages
        }
        
        ChatServices.defaultChatUIService?.configureInputBar(forRecord: shouldEnableRecording)
    }
    
    //==================================================//
    
    /* MARK: - View Manipulation */
    
    public func promptToInvite() {
        let alert = AKAlert(message: "It doesn't appear that any of your contacts have an account with us.\n\nWould you like to send them an invite to sign up?",
                            actions: [AKAction(title: "Send Invite",
                                               style: .preferred)],
                            sender: subview(for: "selectContactButton"))
        alert.present { (actionID) in
            guard actionID != -1 else { return }
            RuntimeStorage.store(true, as: .wantsToInvite)
            StateProvider.shared.wantsToInvite = true
        }
    }
    
    public func updateAppearance() {
        let darkColorToUse = ThemeService.currentTheme == AppThemes.default ? UIColor.listViewBackgroundColor : UIColor.encapsulatingViewBackgroundColor
        backgroundColor = delegate.traitCollection.userInterfaceStyle == .dark ? darkColorToUse : UIColor.white.withAlphaComponent(0.98)
        
        addVerticalBorders(color: recipientBarBorderColor,
                           height: 0.3)
        
        guard let contactEnclosingView = subview(for: "contactEnclosingView"),
              let contactLabel = contactEnclosingView.subview(Core.ui.nameTag(for: "contactLabel")) as? UILabel,
              contactLabel.textColor != .white,
              contactEnclosingView.backgroundColor != .clear else { return }
        
        let selectionColor = UIColor(hex: delegate.traitCollection.userInterfaceStyle == .dark ? 0x2A2A2C : 0xECF0F1)
        contactEnclosingView.backgroundColor = selectionColor
        contactEnclosingView.layer.borderColor = selectionColor.cgColor
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: UITextFieldDelegate */
extension RecipientBar: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let number = textField.text!.digits
        guard number.lowercasedTrimmingWhitespace != "" else {
            guard textField.text!.lowercasedTrimmingWhitespace != "" else {
                delegate.messageInputBar.inputTextView.becomeFirstResponder()
                return false
            }
            
            selectedContactPair = ContactPair(contact: .empty(), numberPairs: nil)
            showSelectedContact(name: textField.text!)
            return false
        }
        
        handleNumberEntered(number)
        Core.gcd.after(milliseconds: 100) {
            textField.resignFirstResponder()
        }
        
        return true
    }
}

/* MARK: UITableViewDataSource, UITableViewDelegate */
extension RecipientBar: UITableViewDataSource, UITableViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let recipientTextField = subview(for: "recipientTextField") as? UITextField else { return }
        recipientTextField.resignFirstResponder()
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return tableViewSections.count
    }
    
    public func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return tableViewSections.map { $0.letter }
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "contactCell", for: indexPath) as! ContactCell
        
        let section = tableViewSections[indexPath.section]
        let contact = section.contactPairs[indexPath.row].contact ?? Contact(firstName: "",
                                                                             lastName: "",
                                                                             phoneNumbers: [])
        
        var fullName = "\(contact.firstName) \(contact.lastName)"
        cell.nameLabel.text = fullName
        
        var mainAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 17)]
        var alternateAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 17)]
        
        if let users = section.contactPairs[indexPath.row].numberPairs?.users,
           users.allSatisfy({ $0.identifier == RuntimeStorage.currentUserID! }) {
            mainAttributes[.foregroundColor] = UIColor.gray
            alternateAttributes[.foregroundColor] = UIColor.gray
            cell.isUserInteractionEnabled = false
            fullName = "\(fullName) \(LocalizedString.myAccount)"
        } else {
            cell.isUserInteractionEnabled = true
        }
        
        cell.nameLabel.attributedText = fullName.attributed(mainAttributes: mainAttributes,
                                                            alternateAttributes: alternateAttributes,
                                                            alternateAttributeRange: [contact.lastName])
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = tableViewSections[indexPath.section]
        let contactPair = section.contactPairs[indexPath.row]
        
        selectedContactPair = contactPair
        handleContactSelected(with: contactPair)
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableViewSections[section].contactPairs.count
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tableViewSections[section].letter
    }
}

/* MARK: UIView */
private extension UIView {
    func addVerticalBorders(color: CGColor? = nil,
                            height: CGFloat? = nil) {
        let borderHeight = height ?? 0.3
        let borderColor = color ?? UIColor.gray.cgColor
        
        layer.sublayers?.removeAll(where: { $0.frame.height == borderHeight && $0.backgroundColor == borderColor })
        
        let topBorder = CALayer()
        let bottomBorder = CALayer()
        
        topBorder.frame = CGRect(x: 0.0,
                                 y: 0.0,
                                 width: frame.size.width,
                                 height: borderHeight)
        topBorder.backgroundColor = borderColor
        
        bottomBorder.frame = CGRect(x: 0,
                                    y: frame.size.height - borderHeight,
                                    width: frame.size.width,
                                    height: borderHeight)
        bottomBorder.backgroundColor = borderColor
        
        layer.addSublayer(topBorder)
        layer.addSublayer(bottomBorder)
    }
}
