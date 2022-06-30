//
//  ContentView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

//==================================================//

/* MARK: - Views */

public enum Page {
    case main
    case home
    case signIn
    case signUp_phoneNumber
    case signUp_verifyPhoneNumber(identifier: String,
                                  phoneNumber: Int)
    case signUp_verifyInfo(userID: String,
                           phoneNumber: Int)
}

public class ViewRouter: ObservableObject {
    @Published var currentPage: Page? = currentUserID == "" ? .main : .home
}

public struct ContentView: View {
    @StateObject public var viewRouter: ViewRouter
    
    public var body: some View {
        switch viewRouter.currentPage {
        case .main:
            MainPageView(viewModel: MainPageViewModel(), viewRouter: viewRouter)
                .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
                .zIndex(1)
        case .home:
            HomePageView(viewModel: HomePageViewModel(),
                         viewRouter: viewRouter)
                .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
                .zIndex(1)
        case .signIn:
            SignInPageView(viewModel: SignInPageViewModel(), viewRouter: viewRouter)
                .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
                .zIndex(1)
        case .signUp_phoneNumber:
            PhoneNumberPageView(viewModel: PhoneNumberPageViewModel(), viewRouter: viewRouter)
                .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
                .zIndex(1)
        case .signUp_verifyPhoneNumber(let identifier,
                                       let phoneNumber):
            VerifyPhoneNumberPageView(viewModel: VerifyPhoneNumberPageViewModel(),
                                      viewRouter: viewRouter,
                                      verificationIdentifier: identifier,
                                      phoneNumber: phoneNumber)
                .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
                .zIndex(1)
        case .signUp_verifyInfo(let userID,
                                let phoneNumber):
            VerifyInfoPageView(viewModel: VerifyInfoPageViewModel(),
                               viewRouter: viewRouter,
                               userID: userID,
                               phoneNumber: phoneNumber)
                .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
                .zIndex(1)
        default:
            MainPageView(viewModel: MainPageViewModel(), viewRouter: viewRouter)
                .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
                .zIndex(1)
        }
    }
}

//==================================================//

/* MARK: - Previews */

public struct ContentView_Previews: PreviewProvider {
    public static var previews: some View {
        //        ContentView(viewModel: ContentViewModel(text: "hello"))
        ContentView(viewRouter: ViewRouter())
    }
}
