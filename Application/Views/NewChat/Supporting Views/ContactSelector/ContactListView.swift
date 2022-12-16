//
//  ContactListView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 30/10/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

public struct ContactListView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @State public var contactPairs: [ContactPair]
    @Binding public var searchQuery: String
    @Binding public var selectedContactPair: ContactPair?
    @Binding public var isPresenting: Bool
    
    private enum Filter {
        case normal
        case basedOnSearch(query: String)
    }
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        List {
            ForEach("ABCDEFGHIJKLMNOPQRSTUVWXYZ#".characterArray, id: \.self) { letter in
                let contacts = (searchQuery.isEmpty ? contacts(.normal) : contacts(.basedOnSearch(query: searchQuery))).filter({ $0.lastName.starts(with: letter) })
                
                if !contacts.isEmpty {
                    Section(header: Text(letter)) {
                        ForEach(contacts) { contact in
                            let pair = contactPairs.filter({ $0.contact.hash == contact.hash }).first!
                            
                            Button {
                                selectedContactPair = pair
                                isPresenting = false
                            } label: {
                                HStack(alignment: .firstTextBaseline,
                                       spacing: 3.5) {
                                    Text(contact.firstName)
                                    Text(contact.lastName).font(Font.body.bold())
                                }
                            }
                        }
                    }.id(letter)
                }
            }
        }
        .environment(\.defaultMinListRowHeight, 44)
        .listStyle(.inset)
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func contacts(_ filter: Filter) -> [Contact] {
        let contacts = contactPairs.contacts.filter({ !($0.firstName == "" && $0.lastName == "") }).sorted(by: { $0.lastName < $1.lastName })
        
        switch filter {
        case .normal:
            return contacts
        case .basedOnSearch(query: let query):
            return contacts.filter({ "\($0)".lowercased().contains(query.lowercased()) })
        }
    }
}
