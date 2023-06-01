//
//  PermissionsPageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 03/01/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import SwiftUI

/* Third-party Frameworks */
import Translator

public struct PermissionsPageView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Booleans
    @State private var grantedContactPermission: Bool?
    @State private var grantedNotificationPermission: Bool?
    @State private var pressedContinue = false
    
    // Other
    @StateObject public var viewModel: PermissionsPageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    // Strings
    @State public var phoneNumber: String
    @State public var region: String
    @State public var userID: String
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear(perform: viewModel.load)
        case .loading:
            ProgressView("" /*"Loading..."*/)
        case .loaded(let translations):
            loadedView(translations)
        case .failed(let exception):
            FailureView(exception: exception) { viewModel.load() }
        }
    }
    
    private func loadedView(_ translations: [String: Translation]) -> some View {
        return VStack {
            TitleSubtitleView(translations: translations)
            
            VStack(alignment: .center) {
                capsuleButton(title: translations["contactPrompt"]!.output,
                              isCompleted: grantedContactPermission) {
                    requestContactPermission()
                }
                
                capsuleButton(title: translations["notificationPrompt"]!.output,
                              isCompleted: grantedNotificationPermission) {
                    requestNotificationPermission()
                }
            }
            .padding(.top, 80)
            .padding(.bottom, 45)
            
            Button {
                createUser()
                pressedContinue = true
            } label: {
                Text(translations["finish"]!.output)
                    .bold()
            }
            .padding(.top, 5)
            .accentColor(.blue)
            .disabled(grantedContactPermission == nil || grantedNotificationPermission == nil)
            .disabled(pressedContinue)
            
            Button {
                viewRouter.currentPage = .signUp_verifyNumber
            } label: {
                Text(translations["back"]!.output)
            }
            .padding(.top, 2)
            .foregroundColor(.blue)
            .font(.system(size: 15))
            
            Spacer()
        }
        .onAppear { RuntimeStorage.store(#file, as: .currentFile) }
    }
    
    //==================================================//
    
    /* MARK: - Supporting Views */
    
    private func capsuleButton(title: String,
                               isCompleted: Bool? = nil,
                               action: @escaping() -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: isCompleted == nil ? "questionmark.circle.fill" : (isCompleted! ? "checkmark.circle.fill" : "x.circle.fill"))
                    .padding(.trailing, 3)
                    .font(.system(size: 30))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.white, isCompleted == nil ? .orange : (isCompleted! ? .green : .red))
                
                Text(title)
                    .foregroundColor(isCompleted == nil ? .white : .gray)
                    .font(.system(size: 15))
                    .bold()
            }
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .foregroundColor(.blue)
        .disabled(isCompleted == nil ? false : true)
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func createUser() {
        viewModel.createUser(identifier: userID,
                             phoneNumber: phoneNumber,
                             region: region) { exception in
            guard exception == nil else {
                self.pressedContinue = false
                Logger.log(exception!,
                           with: .errorAlert)
                return
            }
            
            RuntimeStorage.store(true, as: .isFirstLaunchFromSetup)
            
            RuntimeStorage.store(userID, as: .currentUserID)
            AnalyticsService.logEvent(.signUp)
            
            viewRouter.currentPage = .conversations
            RuntimeStorage.remove(.numberFromSignIn)
        }
    }
    
    private func requestContactPermission() {
        PermissionService.requestPermission(for: .contacts) { status, exception in
            self.grantedContactPermission = status == .granted
            
            guard status == .granted else {
                self.pressedContinue = false
                guard let exception else {
                    Core.gcd.after(milliseconds: 500) { PermissionService.presentCTA(for: .contacts) { } }
                    return
                }
                Logger.log(exception, with: .errorAlert)
                return
            }
            
            if let archivedHashes = UserDefaults.standard.value(forKey: UserDefaultsKeys.archivedLocalUserHashesKey) as? [String] {
                RuntimeStorage.store(archivedHashes, as: .archivedLocalUserHashes)
            } else {
                ContactService.getLocalUserHashes { hashes, exception in
                    guard let hashes else {
                        Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                                   with: .errorAlert)
                        return
                    }
                    
                    UserDefaults.standard.set(hashes, forKey: UserDefaultsKeys.archivedLocalUserHashesKey)
                    RuntimeStorage.store(hashes, as: .archivedLocalUserHashes)
                }
            }
        }
    }
    
    private func requestNotificationPermission() {
        PermissionService.requestPermission(for: .notifications) { status, exception in
            self.grantedNotificationPermission = status == .granted
            
            guard status == .granted else {
                self.pressedContinue = false
                guard let exception else {
                    Core.gcd.after(milliseconds: 500) { PermissionService.presentCTA(for: .notifications) { } }
                    return
                }
                Logger.log(exception, with: .errorAlert)
                return
            }
            
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }
}
