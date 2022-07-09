//
//  RegionMenu.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 09/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import SwiftUI

public struct RegionMenu: View {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    @Binding public var selectedRegion: String
    public var initialRegion: String?
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        Menu {
            ForEach(regionTitleArray().reversed(),
                    id: \.self) { title in
                VStack {
                    Button {
                        selectedRegion = getRegionCode(forRegionTitle: title) ?? "US"
                    } label: {
                        Text(title)
                        Image(uiImage: getImage(for: .regionTitle,
                                                with: title) ?? UIImage())
                    }
                }
            }
        } label: {
            VStack {
                Image(uiImage: getImage(for: .regionCode,
                                        with: selectedRegion) ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30,
                           height: 30)
                Text("+\(callingCodeDictionary[selectedRegion] ?? "1")")
                    .multilineTextAlignment(.center)
                    .scaledToFill()
            }
        }
        .multilineTextAlignment(.center)
        .background(RoundedRectangle(cornerRadius: 6)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                        .padding(.all, -3))
        .onAppear(perform: {
            selectedRegion = initialRegion ?? Locale.current.regionCode ?? "US"
        })
    }
    
    //==================================================//
    
    /* MARK: - Enumerated Type Declarations */
    
    private enum RegionType {
        case regionCode
        case regionTitle
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func getImage(for: RegionType, with: String) -> UIImage? {
        let keys = Array(callingCodeDictionary.keys)
        let matches = `for` == .regionCode ? keys.filter({ $0 == with }) : keys.filter({ getRegionTitle(forRegionCode: $0) == with })
        
        guard matches.count > 0 else {
            return nil
        }
        
        guard let image = UIImage(named: "\(matches.first!.lowercased()).png") else {
            return nil
        }
        
        return image
    }
    
    private func getRegionCode(forRegionTitle: String) -> String? {
        let matches = Array(callingCodeDictionary.keys).filter({ getRegionTitle(forRegionCode: $0) == forRegionTitle })
        
        guard matches.count > 0 else {
            return nil
        }
        
        return matches.first!
    }
    
    private func getRegionTitle(forRegionCode: String) -> String {
        guard callingCodeDictionary[forRegionCode] != nil else {
            return ""
        }
        
        let currentLocale = Locale(identifier: languageCode)
        let regionName = currentLocale.localizedString(forRegionCode: forRegionCode)
        
        if let name = regionName {
            return "\(name) (+\(callingCodeDictionary[forRegionCode]!))"
        } else {
            return "+\(callingCodeDictionary[forRegionCode]!)"
        }
    }
    
    private func regionTitleArray() -> [String] {
        var titleArray = [String]()
        
        for key in callingCodeDictionary.keys {
            titleArray.append(getRegionTitle(forRegionCode: key))
        }
        
        return titleArray.sorted()
    }
}
