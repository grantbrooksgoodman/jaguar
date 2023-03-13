//
//  NewChatPageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 12/11/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import SwiftUI

/* Third-party Frameworks */
import Translator
import AlertKit

public struct NewChatPageView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @StateObject public var viewModel: NewChatPageViewModel
    
    //Booleans
    @Binding public var isPresenting: Bool
    
    @State private var showingContactSelector = false
    
    // Other
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedContactPair: ContactPair?
    @ObservedObject private var stateProvider = StateProvider.shared
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear(perform: viewModel.load)
        case .loading:
            ProgressView("" /*"Loading..."*/)
        case .loaded(let translations,
                     let contactPairs):
            loadedView(translations: translations,
                       contactPairs: contactPairs)
            .onAppear { AnalyticsService.logEvent(.accessNewChatPage) }
        case .failed(let exception):
            Color.clear.onAppear {
                isPresenting = false
                
                Core.gcd.after(seconds: 1) {
                    AKErrorAlert(error: exception.asAkError()).present()
                }
            }
        }
    }
    
    public func loadedView(translations: [String: Translator.Translation],
                           contactPairs: [ContactPair]) -> some View {
        Group {
            NavigationView {
                VStack {
                    var conversationToUse = Conversation.empty()
                    ChatPageView(conversation: Binding(get: { return conversationToUse },
                                                       set: { conversationToUse = $0 }))
                    .onDisappear { Core.ui.resetNavigationBarAppearance() }
                }
                .navigationBarTitle(LocalizedString.newMessage,
                                    displayMode: .inline)
                .interactiveDismissDisabled(true)
                .toolbar {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(translations["cancel"]!.output) {
                            dismiss()
                        }
                    }
                }
                .onChange(of: stateProvider.tappedSelectContactButton) { newValue in
                    guard newValue else { return }
                    showingContactSelector = true
                }
                .onChange(of: stateProvider.tappedDone) { newValue in
                    guard newValue else { return }
                    dismiss()
                }
                .onChange(of: stateProvider.wantsToInvite) { newValue in
                    guard newValue else { return }
                    stateProvider.wantsToInvite = false
                    handleContactSelectorDismissed()
                }
                .onChange(of: stateProvider.showNewChatPageForGrantedContactAccess) { newValue in
                    guard !newValue else { return }
                    showingContactSelector = true
                }
            }
            .sheet(isPresented: $showingContactSelector) {
                ContactSelectorView(isPresenting: $showingContactSelector,
                                    selectedContactPair: $selectedContactPair,
                                    contactPairs: contactPairs.uniquePairs)
                .onAppear {
                    selectedContactPair = nil
                    RuntimeStorage.store(false, as: .isSendingMessage)
                }
                .onDisappear {
                    handleContactSelectorDismissed()
                }
            }
        }
        .onAppear { RuntimeStorage.store(#file, as: .currentFile) }
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func dismiss() {
        RuntimeStorage.messagesVC?.messageInputBar.inputTextView.resignFirstResponder()
        RuntimeStorage.messagesVC?.messageInputBar.alpha = 0
        isPresenting = false
        
        RuntimeStorage.remove(.contactPairs)
    }
    
    private func handleContactSelectorDismissed() {
        if let pair = selectedContactPair {
            guard let messagesVC = RuntimeStorage.messagesVC,
                  let recipientBar = messagesVC.recipientBar else { return }
            recipientBar.handleContactSelected(with: pair)
        } else if RuntimeStorage.wantsToInvite! {
            isPresenting = false
            Core.gcd.after(seconds: 2) {
                viewModel.presentInvitation()
                RuntimeStorage.store(false, as: .wantsToInvite)
            }
        } else {
            guard let messagesVC = RuntimeStorage.messagesVC,
                  let recipientBar = messagesVC.recipientBar,
                  let recipientTextField = recipientBar.subview(for: "recipientTextField") as? UITextField else { return }
            recipientTextField.becomeFirstResponder()
        }
    }
}
