//
//  RouterView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

//==================================================//

/* MARK: - Enumerated Type Declarations */

public enum Page {
    case initial
    
    case signUp_selectLanguage
    case signUp_verifyNumber
    case signUp_authCode(identifier: String,
                         phoneNumber: String,
                         region: String)
    
    case signIn(phoneNumber: String?,
                fromSignUp: Bool) //Add region for sign in from sign up flow
    case conversations
}

//==================================================//

/* MARK: - View Router Declaration */

public class ViewRouter: ObservableObject {
    @Published var currentPage: Page? = currentUserID == "" ? .initial : .conversations
}

//==================================================//

/* MARK: - Views */

public struct RouterView: View {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    @StateObject public var viewRouter: ViewRouter
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewRouter.currentPage {
        case .initial:
            InitialPageView(viewModel: InitialPageViewModel(),
                            viewRouter: viewRouter)
                .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
                .zIndex(1)
        case .signUp_verifyNumber:
            VerifyNumberPageView(viewModel: VerifyNumberPageViewModel(),
                                 viewRouter: viewRouter)
                .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
                .zIndex(1)
        case .signUp_authCode(let identifier,
                              let phoneNumber,
                              let region):
            AuthCodePageView(viewModel: AuthCodePageViewModel(),
                             viewRouter: viewRouter,
                             verificationIdentifier: identifier,
                             phoneNumber: phoneNumber,
                             region: region)
                .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
                .zIndex(1)
        case .signUp_selectLanguage:
            SelectLanguagePageView(viewModel: SelectLanguagePageViewModel(),
                                   viewRouter: viewRouter)
                .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
                .zIndex(1)
        case .signIn(let phoneNumber,
                     let fromSignUp):
            SignInPageView(viewModel: SignInPageViewModel(),
                           viewRouter: viewRouter,
                           phoneNumberString: phoneNumber ?? "",
                           fromSignUp: fromSignUp)
                .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
                .zIndex(1)
        case .conversations:
            ConversationsPageView(viewModel: ConversationsPageViewModel(),
                                  viewRouter: viewRouter)
                .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
                .zIndex(1)
            
        default:
            InitialPageView(viewModel: InitialPageViewModel(),
                            viewRouter: viewRouter)
                .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
                .zIndex(1)
        }
    }
}

//==================================================//

/* MARK: - Previews */

//public struct RouterView_Previews: PreviewProvider {
//    public static var previews: some View {
//        RouterView(viewRouter: ViewRouter())
//    }
//}
