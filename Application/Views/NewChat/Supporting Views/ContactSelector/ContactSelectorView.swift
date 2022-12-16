//
//  ContactSelectorView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 22/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

public struct ContactSelectorView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @Binding public var isPresenting: Bool
    @Binding public var selectedContactPair: ContactPair?
    
    @State public var contactPairs: [ContactPair]
    
    @State private var query = ""
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        NavigationView {
            VStack {
                SearchBar(query: $query)
                
                ScrollViewReader { scrollView in
                    HStack {
                        ContactListView(contactPairs: contactPairs,
                                        searchQuery: $query,
                                        selectedContactPair: $selectedContactPair,
                                        isPresenting: $isPresenting)
                        
                        if contactPairs.count > 10 {
                            VStack {
                                VStack {
                                    SectionIndexTitleView(proxy: scrollView,
                                                          titles: sectionTitles(for: contactPairs))
                                    .font(.footnote)
                                    .background(Color.white)
                                }
                                .padding(.trailing, 10)
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        selectedContactPair = nil
                        isPresenting = false
                        
                        RuntimeStorage.store(true, as: .wantsToInvite)
                    } label: {
                        Text(LocalizedString.invite)
                            .font(Font.body.bold())
                    }
                }
                
                ToolbarItem(placement: .destructiveAction) {
                    Button(LocalizedString.cancel) {
                        selectedContactPair = nil
                        isPresenting = false
                    }
                }
            }
            .navigationBarTitle(LocalizedString.contacts, displayMode: .inline)
            .onAppear { RuntimeStorage.store(#file, as: .currentFile) }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func sectionTitles(for contactPairs: [ContactPair]) -> [String] {
        let contacts = contactPairs.contacts.filter({ !($0.firstName == "" && $0.lastName == "") }).sorted(by: { $0.lastName < $1.lastName })
        
        var titles = [String]()
        for contact in contacts {
            guard !contact.lastName.starts(with: titles.last!) else { continue }
            titles.append(String(contact.lastName.first!))
        }
        
        titles.append("#")
        
        return titles
    }
}
