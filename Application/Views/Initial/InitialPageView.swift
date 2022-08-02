//
//  InitialPageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import AlertKit

public struct InitialPageView: View {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    //Other Declarations
    @StateObject public var viewModel: InitialPageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear {
                viewModel.load()
            }
        case .loading:
            ProgressView("" /*"Loading..."*/)
        case .loaded(let translations):
            Image(uiImage: UIImage(named: "Hello.png")!)
                .resizable()
                .frame(width: 150, height: 70)
                .padding(.bottom, 5)
            
            Text(translations["instruction"]!.output)
                .padding(.vertical, 5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            Button {
                viewRouter.currentPage = .signUp_selectLanguage
            } label: {
                Text(translations["continue"]!.output)
                    .bold()
            }
            .padding(.vertical, 5)
            .foregroundColor(.blue)
            
            Button {
                viewRouter.currentPage = .signIn(phoneNumber: nil,
                                                 fromSignUp: false)
            } label: {
                Text(translations["alreadyUse"]!.output)
            }
            .padding(.vertical, 5)
            .foregroundColor(.blue)
        case .failed(let errorDescriptor):
            Text(errorDescriptor)
        }
    }
}
