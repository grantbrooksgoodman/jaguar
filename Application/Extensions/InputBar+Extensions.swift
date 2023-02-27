//
//  InputBar+Extensions.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 26/02/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/* Third-party Frameworks */
import InputBarAccessoryView

/* MARK: InputBarAccessoryView */
extension InputBarAccessoryView {
    override open var canBecomeFirstResponder: Bool {
        return RuntimeStorage.messagesVC?.viewHasLaidOutSubviewsAtLeastOnce ?? false
    }
}

/* MARK: InputBarSendButton */
public extension InputBarSendButton {
    var isRecordButton: Bool {
        return image(for: .normal) == UIImage(named: "Record")
    }
}
