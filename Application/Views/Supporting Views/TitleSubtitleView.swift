//
//  TitleSubtitleView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 09/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import Translator

public struct TitleSubtitleView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @State public var translations: [String: Translation]
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        VStack(alignment: .leading) {
            Text(translations["title"]!.output)
                .bold()
                .font(.title)
                .padding(.bottom, 2)
                .minimumScaleFactor(0.01)
            
            Text(translations["subtitle"]!.output)
                .foregroundColor(.gray)
                .font(.system(size: 14))
                .minimumScaleFactor(0.01)
        }
        .frame(width: UIScreen.main.bounds.width / 2, height: 200, alignment: .topLeading)
        .padding(.trailing, UIScreen.main.bounds.width / 2)
        .padding(.leading, 40)
        .padding(.top, 15)
    }
}
