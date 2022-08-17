//
//  ExpiryOverlayView.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import AlertKit

public struct ExpiryOverlayView: View {
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        VStack {
            Text("")
                .frame(maxWidth: .infinity,
                       maxHeight: .infinity)
        }
        .background(Color.black)
        .frame(maxWidth: .infinity,
               maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
        .onAppear(perform: {
            after(milliseconds: 1500) {
                AKCore.shared.present(.expiryAlert)
            }
        })
    }
}
