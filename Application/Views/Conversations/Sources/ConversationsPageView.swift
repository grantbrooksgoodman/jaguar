//
//  ConversationsPageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 30/06/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import AlertKit
import MessageKit

public struct ConversationsPageView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @StateObject public var viewModel: ConversationsPageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    @State private var showingPopover = false
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear(perform: viewModel.load)
        case .loading:
            ProgressView("" /*"Loading..."*/)
        case .loaded(let translations,
                     let openConversations):
            VStack {
                let conversationsToUse = viewModel.conversationsToUse(for: openConversations)
                
                NavigationView {
                    List {
                        ForEach(0..<conversationsToUse.count, id: \.self, content: { index in
                            let conversation = conversationsToUse[index]
                            
                            MessageCell(conversation: conversation)
                        })
                        .onDelete(perform: viewModel.deleteConversation(at:))
                    }
                    .listStyle(PlainListStyle())
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                viewModel.presentPromptMethodAlert { showContactPopover in
                                    guard let showPopover = showContactPopover else { return }
                                    showingPopover = showPopover
                                }
                            }) {
                                Label("Compose", systemImage: "square.and.pencil")
                            }
                            .sheet(isPresented: $showingPopover) {
                                NewConversationPageView(viewModel: NewConversationPageViewModel(),
                                                        isPresenting: $showingPopover)
                                .onDisappear {
                                    viewModel.routeNavigationWithSelectedContactPair()
                                }
                            }
                        }
                    }
                    .navigationBarTitle(translations["messages"]!.output)
                }
                .onAppear() {
                    RuntimeStorage.store(openConversations, as: .conversations)
                }
            }
            .onShake(perform: {
                self.confirmSequenceUser()
            })
            .onAppear { RuntimeStorage.store(#file, as: .currentFile) }
        case .failed(let errorDescriptor):
            Text(errorDescriptor)
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func confirmSequenceUser() {
        let confirmationAlert = AKConfirmationAlert(message: "Sign in next user?",
                                                    confirmationStyle: .default)
        
        confirmationAlert.present { didConfirm in
            if didConfirm == 1 {
                UserTestingSerializer.shared.signInNextUserInSequence { errorDescriptor in
                    guard errorDescriptor == nil else {
                        Logger.log(errorDescriptor ?? "An unknown error occurred.",
                                   with: .errorAlert,
                                   metadata: [#file, #function, #line])
                        return
                    }
                    
                    ConversationArchiver.clearArchive()
                    
                    RuntimeStorage.store(RuntimeStorage.currentUser!.languageCode!, as: .languageCode)
                    AKCore.shared.setLanguageCode(RuntimeStorage.currentUser!.languageCode)
                    
                    Core.gcd.after(milliseconds: 100) {
                        //                                setUpConversationArchive()
                        viewModel.load()
                    }
                }
            }
        }
    }
}
