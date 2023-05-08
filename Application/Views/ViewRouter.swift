//
//  ViewRouter.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

//==================================================//

/* MARK: - Enums */

public enum Page {
    case initial
    
    case signUp_selectLanguage
    case signUp_verifyNumber
    case signUp_authCode(identifier: String,
                         phoneNumber: String,
                         region: String)
    case signUp_permissions(phoneNumber: String,
                            region: String,
                            userID: String)
    
    case signIn(phoneNumber: String?) // Add region for sign in from sign up flow
    case conversations
}

//==================================================//

/* MARK: - View Router Declaration */

public class ViewRouter: ObservableObject {
    @Published var currentPage: Page? = RuntimeStorage.currentUserID == nil ? .initial : RuntimeStorage.currentUserID! == "" ? .initial : .conversations
}

//==================================================//

/* MARK: - Views */

public struct RouterView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
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
        case .signUp_selectLanguage:
            SelectLanguagePageView(viewModel: SelectLanguagePageViewModel(),
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
                             phoneNumber: phoneNumber,
                             region: region,
                             verificationIdentifier: identifier)
            .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
            .zIndex(1)
        case .signUp_permissions(let phoneNumber,
                                 let region,
                                 let userID):
            PermissionsPageView(viewModel: PermissionsPageViewModel(),
                                viewRouter: viewRouter,
                                phoneNumber: phoneNumber,
                                region: region,
                                userID: userID)
            .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
            .zIndex(1)
        case .signIn(let phoneNumber):
            SignInPageView(viewModel: SignInPageViewModel(),
                           viewRouter: viewRouter,
                           phoneNumberString: phoneNumber ?? "")
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

// public struct RouterView_Previews: PreviewProvider {
//    public static var previews: some View {
//        RouterView(viewRouter: ViewRouter())
//    }
// }
