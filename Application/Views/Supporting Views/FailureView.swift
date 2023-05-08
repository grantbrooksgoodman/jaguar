//
//  FailureView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 26/03/2023.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import AlertKit

public struct FailureView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @State public var exception: Exception
    @State public var retryHandler: (()->())? = nil
    
    @State private var reportedBug = false
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        Image(systemName: "exclamationmark.octagon.fill")
            .renderingMode(.template)
            .foregroundColor(.red)
            .font(.system(size: 60))
            .padding(.bottom, 5)
        
        Text(exception.userFacingDescriptor)
            .font(Font.custom("SFUIText-Semibold", size: 17))
            .foregroundColor(Color(uiColor: .secondaryLabel))
            .padding(.vertical, 5)
            .multilineTextAlignment(.center)
        
        if retryHandler != nil {
            Button {
                retryHandler?()
            } label: {
                Text(LocalizedString.tryAgain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
            .padding(.top, 5)
        }
        
        Button {
            guard Build.isOnline else {
                AKCore.shared.connectionAlertDelegate()?.presentConnectionAlert()
                return
            }
            
            AKCore.shared.reportDelegate().fileReport(error: exception.asAkError())
            reportedBug = true
        } label: {
            Text(LocalizedString.reportBug)
                .font(.system(size: 14))
                .foregroundColor(reportedBug ? Color(uiColor: .systemGray) : .blue)
        }
        .disabled(reportedBug)
        .padding(.top, 5)
    }
}
