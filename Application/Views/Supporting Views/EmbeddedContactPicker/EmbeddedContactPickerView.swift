//
//  EmbeddedContactPickerView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 22/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI
import Contacts
import Combine

public struct EmbeddedContactPickerView: UIViewControllerRepresentable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public typealias UIViewControllerType = EmbeddedContactPickerController
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    public func makeUIViewController(context: UIViewControllerRepresentableContext<EmbeddedContactPickerView>) -> EmbeddedContactPickerView.UIViewControllerType {
        let result = EmbeddedContactPickerView.UIViewControllerType()
        result.delegate = context.coordinator
        
        return result
    }
    
    public func updateUIViewController(_ uiViewController: EmbeddedContactPickerView.UIViewControllerType, context: UIViewControllerRepresentableContext<EmbeddedContactPickerView>) {
        
    }
    
    //==================================================//
    
    /* MARK: - Coordinator Class Declaration */
    
    public final class Coordinator: NSObject, EmbeddedContactPickerControllerDelegate {
        
        public func embeddedContactPickerController(_ viewController: EmbeddedContactPickerController, didSelect contact: CNContact) {
            //            selectedContact = contact
            viewController.dismiss(animated: true)
        }
        
        public func embeddedContactPickerControllerDidCancel(_ viewController: EmbeddedContactPickerController) {
            //            selectedContact = nil
            viewController.dismiss(animated: true)
        }
    }
}
