//
//  EmbeddedContactPickerController.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 22/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import Contacts
import ContactsUI

//==================================================//

/* MARK: - Protocol Declarations */

public protocol EmbeddedContactPickerControllerDelegate: AnyObject {
    func embeddedContactPickerControllerDidCancel(_ viewController: EmbeddedContactPickerController)
    
    func embeddedContactPickerController(_ viewController: EmbeddedContactPickerController,
                                         didSelect contact: CNContact)
}

//==================================================//

/* MARK: - Class Declarations */

public class EmbeddedContactPickerController: UIViewController, CNContactPickerDelegate {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    public weak var delegate: EmbeddedContactPickerControllerDelegate?
    
    //==================================================//
    
    /* MARK: - Overridden Functions */
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.open(animated: animated)
    }
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        self.dismiss(animated: false) {
            self.delegate?.embeddedContactPickerControllerDidCancel(self)
        }
    }
    
    public func contactPicker(_ picker: CNContactPickerViewController,
                              didSelect contact: CNContact) {
        self.dismiss(animated: false) {
            self.delegate?.embeddedContactPickerController(self,
                                                           didSelect: contact)
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func open(animated: Bool) {
        let viewController = CNContactPickerViewController()
        viewController.delegate = self
        
        self.present(viewController, animated: false)
    }
}
