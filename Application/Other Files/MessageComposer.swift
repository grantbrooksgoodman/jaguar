//
//  MessageComposer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 30/10/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import MessageUI

/* Third-party Frameworks */
import AlertKit

public final class MessageComposer: NSObject, MFMessageComposeViewControllerDelegate {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static let shared = MessageComposer()
    
    //==================================================//
    
    /* MARK: - Protocol Compliance */
    
    public func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                             didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
    }
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public func compose(withContent content: String) {
        guard MFMessageComposeViewController.canSendText() else {
            let exception = Exception("Unable to send texts.",
                                      isReportable: false,
                                      metadata: [#file, #function, #line])
            
            let translateDescriptor = exception.userFacingDescriptor != exception.descriptor
            AKErrorAlert(error: exception.asAkError(),
                         shouldTranslate: translateDescriptor ? [.all] : [.actions(indices: nil),
                                                                          .cancelButtonTitle],
                         networkDependent: true).present()
            
            return
        }
        
        let compositionVC = MFMessageComposeViewController()
        compositionVC.messageComposeDelegate = self
        compositionVC.body = content
        
        Core.ui.politelyPresent(viewController: compositionVC)
    }
}
