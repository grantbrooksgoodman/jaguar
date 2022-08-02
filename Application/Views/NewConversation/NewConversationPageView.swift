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

public struct NewConversationPageView: View {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    @State private var contacts = [ContactInfo.init(firstName: "",
                                                    lastName: "",
                                                    phoneNumber: nil)]
    @State private var searchText = ""
    @State private var showCancelButton: Bool = false
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        VStack {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    
                    TextField("search", text: self.$searchText, onEditingChanged: { isEditing in
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
                ForEach (self.contacts.filter({ (contact) -> Bool in
                    self.searchText.isEmpty ? true :
                        "\(contact)".lowercased().contains(self.searchText.lowercased())
                })) { contact in
                    ContactCell(contact: contact)
                }
            }.onAppear() {
                self.requestAccess()
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func getContacts() {
        DispatchQueue.main.async {
            self.contacts = ContactsServer.fetchAllContacts()
        }
    }
    
    private func requestAccess() {
        let contactStore = CNContactStore()
        
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            self.getContacts()
        case .denied:
            contactStore.requestAccess(for: .contacts) { granted,
                                                         error in
                guard granted else {
                    Logger.log(error == nil ? "An unknown error occurred." : Logger.errorInfo(error!),
                               metadata: [#file, #function, #line])
                    return
                }
                
                self.getContacts()
            }
        case .restricted, .notDetermined:
            contactStore.requestAccess(for: .contacts) { granted,
                                                         error in
                
                guard granted else {
                    Logger.log(error == nil ? "An unknown error occurred." : Logger.errorInfo(error!),
                               metadata: [#file, #function, #line])
                    return
                }
                
                self.getContacts()
            }
        @unknown default:
            Logger.log("An unknown error occurred.",
                       metadata: [#file, #function, #line])
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
