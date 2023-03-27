//
//  LanguagePickerView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/03/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import Translator

public struct LanguagePickerView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @Binding public var isPresenting: Bool
    public var languages = Array(RuntimeStorage.languageCodeDictionary!.values).sorted()
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var query = ""
    @State private var selectedLanguage = ""
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        NavigationView {
            ScrollViewReader { _ in
                SearchBar(query: $query)
                    .background(appearanceBasedBackgroundColor)
                    .padding(.bottom, 7)
                
                VStack {
                    if languageNames(for: $query.wrappedValue).isEmpty {
                        noResultsView
                    } else {
                        languageListView
                    }
                }
                .toolbar {
                    cancelButton
                    doneButton
                }
                .navigationBarTitle(LocalizedString.selectLanguage, displayMode: .inline)
                .interactiveDismissDisabled(true)
            }
            .background(appearanceBasedBackgroundColor)
        }
    }
    
    //==================================================//
    
    /* MARK: - Toolbar Buttons */
    
    @ToolbarContentBuilder
    private var cancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(LocalizedString.cancel) {
                isPresenting = false
            }
        }
    }
    
    @ToolbarContentBuilder
    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(LocalizedString.done) {
                isPresenting = false
            }
            .disabled(selectedLanguage == "")
        }
    }
    
    //==================================================//
    
    /* MARK: - View Builders */
    
    private var appearanceBasedBackgroundColor: some View {
        guard colorScheme == .dark else {
            return Color(uiColor: UIColor(hex: 0xF8F8F8))
        }
        
        return Color(uiColor: UIColor(hex: 0x2A2A2C))
    }
    
    private func cellLabel(for language: String) -> some View {
        HStack {
            Text(language)
                .font(Font.system(size: 17, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            if language == selectedLanguage {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .padding(.leading, 3)
            }
        }
    }
    
    private var languageListView: some View {
        List(languageNames(for: $query.wrappedValue),
             id: \.self) { title in
            Button {
                selectedLanguage = title
                guard let languageCodes = RuntimeStorage.languageCodeDictionary else { return }
                
                var language = languageCodes.values.first(where: { title.trimmingBorderedWhitespace.contains($0.components(separatedBy: "(").last!) })
                if language == nil {
                    language = languageCodes.values.first(where: { $0.contains(title.trimmingBorderedWhitespace) })
                }
                
                guard let language else { return }
                let selectedLanguageCode = languageCodes.allKeys(forValue: language).first!
                RuntimeStorage.store(selectedLanguageCode, as: .invitationLanguageCode)
            } label: {
                cellLabel(for: title)
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
    
    //==================================================//
    
    /* MARK: - Helper Methods */
    
    private func languageNames(for query: String) -> [String] {
        let languageNames = localizedLanguageNames()
        guard query != "" else { return languageNames }
        
        var matches = [String]()
        for name in languageNames {
            guard name.lowercasedTrimmingWhitespace.contains(query.lowercasedTrimmingWhitespace) else { continue }
            matches.append(name)
        }
        
        return matches.sorted()
    }
    
    private func localizedLanguageNames() -> [String] {
        let locale = Locale(identifier: RuntimeStorage.languageCode!)
        
        var localizedNames = [String]()
        for (code, name) in RuntimeStorage.languageCodeDictionary! {
            guard let localizedName = locale.localizedString(forLanguageCode: code) else {
                localizedNames.append(name)
                continue
            }
            
            let components = name.components(separatedBy: "(")
            guard components.count == 2 else {
                let suffix = localizedName.lowercased() == name.lowercased() ? "" : "(\(name))"
                localizedNames.append("\(localizedName.firstUppercase) \(suffix)")
                continue
            }
            
            let endonym = components[1]
            let suffix = localizedName.lowercased() == endonym.lowercased().dropSuffix() ? "" : "(\(endonym)"
            localizedNames.append("\(localizedName.firstUppercase) \(suffix)")
        }
        
        return localizedNames.sorted()
    }
}
