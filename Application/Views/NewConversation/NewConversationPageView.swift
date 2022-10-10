//
//  NewConversationPageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 22/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import ContactsUI
import SwiftUI

/* Third-party Frameworks */
import PhoneNumberKit

public struct NewConversationPageView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @StateObject public var viewModel: NewConversationPageViewModel
    
    @State private var searchText = ""
    @State private var showCancelButton: Bool = false
    @Binding public var isPresenting: Bool
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear(perform: viewModel.load)
        case .loading:
            ProgressView("")
        case .loaded(translations: let translations):
            VStack {
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        
                        TextField(translations["search"]!.output, text: self.$searchText, onEditingChanged: { isEditing in
                            self.showCancelButton = true
                        })
                        
                        Button(action: {
                            self.searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .opacity(self.searchText == "" ? 0 : 1)
                        }
                    }
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    
                    if self.showCancelButton  {
                        Button("Cancel") {
                            UIApplication.shared.endEditing(true)
                            self.searchText = ""
                            self.showCancelButton = false
                        }
                    }
                }
                .padding([.leading, .trailing,.top])
                
                List {
                    ForEach (viewModel.contacts.contacts.sorted(by: { $0.lastName < $1.lastName }).filter({ (contact) -> Bool in
                        self.searchText.isEmpty ? true :
                        "\(contact)".lowercased().contains(self.searchText.lowercased())
                    })) { contact in
                        let contactPair = viewModel.contacts.filter({ $0.contact.hash == contact.hash }).first!
                        
                        if contact.firstName != "" || contact.lastName != "" {
                            if contactPair.users != nil {
                                Button("\(contact.firstName) \(contact.lastName)") {
                                    isPresenting = false
                                    RuntimeStorage.store(contactPair, as: .selectedContactPair)
                                }
                            } else {
                                Text("\(contact.firstName) \(contact.lastName)")
                            }
                        }
                    }
                }
            }.onAppear {
                RuntimeStorage.store(#file, as: .currentFile)
                viewModel.requestAccess()
            }
        case .failed(let errorDescriptor):
            Text(errorDescriptor)
        }
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: UIApplication */
extension UIApplication {
    func endEditing(_ force: Bool) {
        self.windows
            .filter{$0.isKeyWindow}
            .first?
            .endEditing(force)
    }
}
