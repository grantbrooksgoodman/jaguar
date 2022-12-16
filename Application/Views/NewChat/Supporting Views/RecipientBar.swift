//
//  RecipientBar.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/11/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI
import UIKit

public class RecipientBar: UIView {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Arrays
    private var contactPairs = [ContactPair]()
    private var queriedContactPairs = [ContactPair]()
    private var tableViewSections = [TableViewSection]()
    
    // UITapGestureRecognizers
    private var deselectContactGesture: UITapGestureRecognizer!
    private var toggleContactSelectedGesture: UITapGestureRecognizer!
    
    // Other
    public let delegate: ChatPageViewController!
    public var selectedContactPair: ContactPair?
    
    private var contactTableView: UITableView!
    private var isAnimating = false
    
    private struct TableViewSection {
        let letter: String
        let contactPairs: [ContactPair]
    }
    
    //==================================================//
    
    /* MARK: - Constructor Functions */
    
    public init(delegate: ChatPageViewController) {
        self.delegate = delegate
        
        super.init(frame: CGRect(x: 0,
                                 y: 0,
                                 width: UIScreen.main.bounds.width,
                                 height: 54))
        
        addVerticalBorders(color: UIColor.quaternaryLabel.cgColor,
                           height: 0.3)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //==================================================//
    
    /* MARK: - Overridden Functions */
    
    public override func layoutSubviews() {
        if delegate.view.subviews.filter({ $0 is UITableView }).count == 0 {
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
            
            Core.gcd.after(milliseconds: 500) {
                recipientTextField.becomeFirstResponder()
            }
        }
        
        if subviews(for: "selectContactButton").isEmpty {
            let selectContactButton = getSelectContactButton()
            selectContactButton.tag = Core.ui.nameTag(for: "selectContactButton")
            addSubview(selectContactButton)
            
            Core.gcd.after(milliseconds: 500) {
                guard !self.isAnimating else { return }
                selectContactButton.isEnabled = true
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Contact Selection Handler */
    
    /// - Warning: Not implemented yet.
    private func displayExistingChat(with userID: String) {
        if let openConversations = RuntimeStorage.currentUser!.openConversations,
           let conversation = openConversations.filter({ $0.participants.userIDs.contains(userID) }).first {
            print(conversation.identifier.key!)
        }
    }
    
    public func handleContactSelected(with contactPair: ContactPair) {
        ContactNavigationRouter.routeNavigation(with: contactPair) { selectedUser, exception in
            if exception?.hashlet == JaguarException.conversationAlreadyExists.description,
               let userID = exception?.extraParams?["UserID"] as? String {
                self.displayExistingChat(with: userID)
                Logger.log(exception!,
                           with: .errorAlert)
            } else if let exception {
                Logger.log(exception,
                           with: .errorAlert)
            } else {
                self.selectedContactPair = contactPair
                self.showSelectedContact(name: "\(contactPair.contact.firstName) \(contactPair.contact.lastName)")
            }
        }
    }
    
    private func handleNumberEntered(_ phoneNumber: String) {
        ContactNavigationRouter.routeNavigation(with: phoneNumber) { selectedUser, exception in
            guard let user = selectedUser else {
                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                           with: .errorAlert)
                return
            }
            
            var regionCode = RegionDetailServer.getRegionCode(forCallingCode: user.callingCode)
            regionCode = (regionCode == "multiple" && user.callingCode == "1") ? "US" : regionCode
            
            let formattedNumber = user.phoneNumber.formattedPhoneNumber(region: regionCode)
            
            self.selectedContactPair = ContactPair(contact: Contact(firstName: "+\(user.callingCode!)",
                                                                    lastName: formattedNumber,
                                                                    phoneNumbers: [PhoneNumber(digits: user.phoneNumber)]),
                                                   users: [user])
            
            var contactName = "+\(user.callingCode!) \(formattedNumber)"
            
            if let name = ContactService.fetchContactName(forNumber: user.phoneNumber) {
                contactName = "\(name.givenName) \(name.familyName)"
            } else if let name = ContactService.fetchContactName(forNumber: "\(user.callingCode!)\(user.phoneNumber!)".digits) {
                contactName = "\(name.givenName) \(name.familyName)"
            }
            
            self.showSelectedContact(name: contactName)
        }
    }
    
    private func showSelectedContact(name: String) {
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
        inputBar.sendButton.isEnabled = inputBar.inputTextView.text.lowercasedTrimmingWhitespace != "" && !useRedColor
        
        Core.gcd.after(milliseconds: 100) {
            if !useRedColor {
                inputBar.inputTextView.placeholder = " \(LocalizedString.newMessage)"
                guard let topViewController = UIApplication.topViewController(),
                      !topViewController.isKind(of: UIAlertController.self) else { return }
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
    
    /* MARK: - Button Action Handlers */
    
    @objc private func clearButtonAction() {
        selectedContactPair = nil
        ContactNavigationRouter.currentlySelectedUser = nil
        
        delegate.messageInputBar.sendButton.isEnabled = false
        
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
        
        guard subviews(for: "selectContactButton").isEmpty else {
            if let button = subview(for: "selectContactButton") as? UIButton {
                button.alpha = 1
            }
            
            return
        }
        
        Logger.log("Adding subview for «selectContactButton».",
                   with: .normalAlert,
                   metadata: [#file, #function, #line])
        
        let selectContactButton = getSelectContactButton()
        selectContactButton.tag = Core.ui.nameTag(for: "selectContactButton")
        selectContactButton.isEnabled = true
        addSubview(selectContactButton)
    }
    
    @objc public func selectContactButtonAction() {
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
        
        guard contactEnclosingView.backgroundColor != .clear else {
            return
        }
        
        contactLabel.textColor = (selectedContactPair?.isEmpty ?? false) ? .systemRed : .systemBlue
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
        guard let contactEnclosingView = subview(for: "contactEnclosingView"),
              let contactLabel = contactEnclosingView.subview(Core.ui.nameTag(for: "contactLabel")) as? UILabel else {
            Logger.log(Exception("Couldn't unwrap subviews.",
                                 metadata: [#file, #function, #line]))
            return
        }
        
        let useRedColor = selectedContactPair?.isEmpty ?? false
        let currentlySelected = contactLabel.textColor == .white
        
        if currentlySelected {
            contactLabel.textColor = useRedColor ? .systemRed : .systemBlue
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
            contactEnclosingView.backgroundColor = useRedColor ? .systemRed : .systemBlue
            contactEnclosingView.layer.borderColor = useRedColor ? UIColor.systemRed.cgColor : UIColor.systemBlue.cgColor
            
            delegate.messageInputBar.inputTextView.resignFirstResponder()
        }
    }
    
    //==================================================//
    
    /* MARK: - Table View Functions */
    
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
        
        guard contactPairs.isEmpty else {
            reset()
            return
        }
        
        ContactService.loadContacts { contactPairs, exception in
            guard let pairs = contactPairs else {
                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            self.contactPairs = pairs
            
            self.contactTableView.dataSource = self
            self.contactTableView.delegate = self
            reset()
        }
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
    }
    
    //==================================================//
    
    /* MARK: - View Builders */
    
    private func getClearButton() -> UIButton? {
        guard let contactEnclosingView = subview(for: "contactEnclosingView") else {
            Logger.log(Exception("Couldn't unwrap subviews.",
                                 metadata: [#file, #function, #line]))
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
        contactLabel.textColor = useRedColor ? .systemRed : .systemBlue
        
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
                                                           width: UIScreen.main.bounds.width - 80,
                                                           height: 54))
        
        recipientTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        recipientTextField.delegate = self
        
        recipientTextField.center.x = center.x
        recipientTextField.frame.origin.x = toLabel.frame.maxX + 5
        
        recipientTextField.autocorrectionType = .no
        recipientTextField.keyboardType = .emailAddress
        recipientTextField.spellCheckingType = .no
        
        return recipientTextField
    }
    
    private func getSelectContactButton() -> UIButton {
        let selectContactButton = UIButton(type: .contactAdd)
        
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
    
    /* MARK: - View Manipulation */
    
    public func updateAppearance() {
        guard let contactEnclosingView = subview(for: "contactEnclosingView") else { return }
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
            
            self.selectedContactPair = ContactPair(contact: Contact(firstName: "",
                                                                    lastName: "",
                                                                    phoneNumbers: []),
                                                   users: nil)
            self.showSelectedContact(name: textField.text!)
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
        
        let fullName = "\(contact.firstName) \(contact.lastName)"
        cell.nameLabel.text = fullName
        
        let mainAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 17)]
        let alternateAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 17)]
        
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
public extension UIView {
    func addVerticalBorders(color: CGColor? = nil,
                            height: CGFloat? = nil) {
        let borderHeight = height ?? 0.3
        let borderColor = color ?? UIColor.gray.cgColor
        
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
        bottomBorder.backgroundColor = UIColor.quaternaryLabel.cgColor
        
        layer.addSublayer(topBorder)
        layer.addSublayer(bottomBorder)
    }
}

/* MARK: UIApplication */
public extension UIApplication {
    class func topViewController(_ base: UIViewController? = UIApplication.shared.windows.first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(selected)
            }
        }
        
        if let presented = base?.presentedViewController {
            return topViewController(presented)
        }
        
        return base
    }
}
