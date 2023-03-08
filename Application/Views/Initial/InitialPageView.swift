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
    
    /* MARK: - Properties */
    
    @StateObject public var viewModel: InitialPageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    @Environment(\.colorScheme) private var colorScheme
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear(perform: viewModel.load)
        case .loading:
            ProgressView("" /*"Loading..."*/)
        case .loaded(let translations):
            VStack {
                Image(uiImage: UIImage(named: "Hello")!)
                    .resizable()
                    .renderingMode(colorScheme == .dark ? .template : .original)
                    .foregroundColor(colorScheme == .dark ? Color(uiColor: UIColor(hex: 0xF8F8F8)) : .none)
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
            }
            .onAppear {
                RuntimeStorage.store(#file, as: .currentFile)
                RuntimeStorage.remove(.numberFromSignIn)
            }
        case .failed(let exception):
            Text(exception.userFacingDescriptor)
        }
    }
}
