//
//  ChatUIService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 19/02/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/* Third-party Frameworks */
import InputBarAccessoryView
import MessageKit

public typealias ChatUIDelegate = ObjCChatUIDelegate & SwiftChatUIDelegate

@objc
public protocol ObjCChatUIDelegate {
    func toggleDoneButton()
}

public protocol SwiftChatUIDelegate {
    // MARK: Properties
    var isUserCancellationEnabled: Bool { get }
    var shouldShowRecordButton: Bool { get }
    
    // MARK: Methods
    func configureInputBar(forRecord: Bool)
    func hideNewChatControls()
    func setUserCancellation(enabled: Bool)
}

public class ChatUIService: ChatService {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    /* Internal */
    public var delegate: ChatUIDelegate
    public var serviceType: ChatServiceType = .chatUI
    
    /* Delegate */
    public var isUserCancellationEnabled: Bool { get { delegate.isUserCancellationEnabled } }
    public var shouldShowRecordButton: Bool { get { delegate.shouldShowRecordButton } }
    
    //==================================================//
    
    /* MARK: - Constructor Method */
    
    public init(delegate: ChatUIDelegate) {
        self.delegate = delegate
    }
    
    //==================================================//
    
    /* MARK: - Delegate Methods */
    
    public func setUserCancellation(enabled: Bool) {
        DispatchQueue.main.async {
            self.delegate.setUserCancellation(enabled: enabled)
        }
    }
    
    public func configureInputBar(forRecord: Bool) {
        delegate.configureInputBar(forRecord: forRecord)
    }
    
    public func hideNewChatControls() {
        delegate.hideNewChatControls()
    }
    
    @objc
    public func toggleDoneButton() {
        delegate.toggleDoneButton()
    }
}
