//
//  RegionMenu.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 09/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

public struct RegionMenu: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @Binding public var selectedRegion: String
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        Menu {
            ForEach(RegionDetailServer.regionTitleArray().reversed(),
                    id: \.self) { title in
                VStack {
                    Button {
                        selectedRegion = RegionDetailServer.getRegionCode(forRegionTitle: title) ?? "US"
                    } label: {
                        Text(title)
                        Image(uiImage: RegionDetailServer.getImage(for: .regionTitle,
                                                                   with: title) ?? UIImage())
                    }
                }
            }
        } label: {
            VStack {
                Image(uiImage: RegionDetailServer.getImage(for: .regionCode,
                                                           with: selectedRegion) ?? UIImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30,
                       height: 30)
                Text("+\(RuntimeStorage.callingCodeDictionary![selectedRegion] ?? "1")")
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
            selectedRegion = RuntimeStorage.selectedRegionCode ?? Locale.current.regionCode ?? "US"
        })
    }
}
