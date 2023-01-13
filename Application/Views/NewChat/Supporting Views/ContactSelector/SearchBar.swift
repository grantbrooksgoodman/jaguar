//
//  SearchBar.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 30/10/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

public struct SearchBar: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @Binding public var query: String
    
    @Environment(\.colorScheme) private var colorScheme
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .imageScale(.medium)
                
                TextField(LocalizedString.search,
                          text: $query)
                .frame(height: 36)
                
                Button(action: {
                    query = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .opacity(query == "" ? 0 : 1)
                }
            }
            .padding(.horizontal, 8)
            .background(Color(uiColor: colorScheme == .dark ? UIColor(hex: 0x3B3A3F) : UIColor(hex: 0xE7E7E9)))
            .cornerRadius(10)
        }
        .padding([.leading, .trailing])
        .background(Color(uiColor: colorScheme == .dark ? UIColor(hex: 0x2A2A2C) : UIColor(hex: 0xF8F8F8)))
    }
}
