//
//  RegionMenu.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 09/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI
import UIKit

public struct RegionMenu: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @Binding public var selectedRegionCode: String
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        ScrollViewReader { proxy in
            Button {
                isExpanded.toggle()
            } label: {
                menuButtonLabel
            }
            .popover(isPresented: $isExpanded) {
                ThemedView(reloadsForUpdates: true) {
                    RegionPicker(isExpanded: $isExpanded, selectedRegionCode: $selectedRegionCode)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .onAppear { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - View Builders */
    
    private var menuButtonLabel: some View {
        VStack {
            Image(uiImage: RegionDetailServer.getImage(for: .regionCode,
                                                       with: selectedRegionCode) ?? UIImage())
            .resizable()
            .frame(width: 40, height: 25)
            .cornerRadius(3)
            .aspectRatio(contentMode: .fit)
            
            Text("+\(RuntimeStorage.callingCodeDictionary![selectedRegionCode] ?? "1")")
                .foregroundColor(Color(uiColor: .systemBlue))
                .multilineTextAlignment(.center)
            
        }
        .frame(minWidth: 45, minHeight: 80)
        .background(RoundedRectangle(cornerRadius: 6))
        .foregroundColor(Color(uiColor: colorScheme == .dark ? UIColor(hex: 0x2A2A2C) : .white))
        .shadow(radius: 2)
    }
}

struct RegionPicker: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @Binding public var isExpanded: Bool
    @Binding public var selectedRegionCode: String
    
    @State private var query = ""
    
    //==================================================//
    
    /* MARK: - View Body */
    
    var body: some View {
        if isExpanded {
            ScrollViewReader { proxy in
                regionListHeaderView
                
                if regionTitles(for: $query.wrappedValue).isEmpty {
                    noResultsView
                } else {
                    regionListView
                        .onAppear {
                            Core.gcd.after(milliseconds: 500) {
                                withAnimation {
                                    proxy.scrollTo(RegionDetailServer.getRegionTitle(forRegionCode: selectedRegionCode),
                                                   anchor: .top)
                                }
                            }
                        }
                }
            }
            .background(Color.navigationBarBackgroundColor)
        } else {
            EmptyView()
        }
    }
    
    //==================================================//
    
    /* MARK: - View Builders */
    
    private func cellLabel(for regionTitle: String) -> some View {
        HStack {
            Image(uiImage: RegionDetailServer.getImage(for: .regionTitle,
                                                       with: regionTitle) ?? UIImage())
            .resizable()
            .frame(width: 40, height: 25)
            .cornerRadius(3)
            .aspectRatio(contentMode: .fit)
            
            Text(regionTitle)
                .font(Font.system(size: 17, weight: .regular))
                .foregroundColor(.titleTextColor)
            
            if let title = RegionDetailServer.getRegionTitle(forRegionCode: selectedRegionCode),
               regionTitle == title {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .padding(.leading, 3)
            }
        }
    }
    
    private var noResultsView: some View {
        Group {
            Spacer()
            Text(LocalizedString.noResults)
                .font(Font.system(size: 18, weight: .regular))
                .foregroundColor(Color(uiColor: .secondaryLabel))
            Spacer()
        }
    }
    
    private var regionListHeaderView: some View {
        Group {
            Text(LocalizedString.selectCallingCode)
                .font(Font.system(size: 17, weight: .medium))
                .frame(maxWidth: .infinity,
                       maxHeight: 54)
                .background(Color.navigationBarBackgroundColor)
            
            SearchBar(query: $query)
                .background(Color.navigationBarBackgroundColor)
                .padding(.bottom, 7)
        }
    }
    
    private var regionListView: some View {
        List(regionTitles(for: $query.wrappedValue),
             id: \.self) { title in
            Button {
                selectedRegionCode = RegionDetailServer.getRegionCode(forRegionTitle: title) ?? "US"
                Core.gcd.after(milliseconds: 500) { self.isExpanded = false }
            } label: {
                cellLabel(for: title)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Helper Methods */
    
    private func regionTitles(for query: String) -> [String] {
        let regionTitles = RegionDetailServer.regionTitleArray()
        guard query != "" else { return regionTitles }
        
        var matches = [String]()
        for title in regionTitles {
            guard title.lowercasedTrimmingWhitespace.contains(query.lowercasedTrimmingWhitespace) else { continue }
            matches.append(title)
        }
        
        return matches
    }
}
