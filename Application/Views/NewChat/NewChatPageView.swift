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
        case .failed(let exception):
            Color.clear.onAppear {
                isPresenting = false
                
                Core.gcd.after(seconds: 1) {
                    viewModel.presentExceptionAlert(exception)
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
                }
                .navigationBarTitle(Localizer.preLocalizedString(for: .newMessage) ?? "New Message",
                                    displayMode: .inline)
                //                .navigationBar(backgroundColor: Color(uiColor: colorScheme == .dark ? UIColor(hex: 0x2A2A2C) : UIColor(hex: 0xF8F8F8)),
                //                               titleColor: colorScheme == .dark ? .white : .black)
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
            }
            .sheet(isPresented: $showingContactSelector) {
                ContactSelectorView(isPresenting: $showingContactSelector,
                                    selectedContactPair: $selectedContactPair,
                                    contactPairs: contactPairs)
                .onAppear {
                    selectedContactPair = nil
                    RuntimeStorage.store(false, as: .isSendingMessage)
                }
                .onDisappear {
                    handleContactSelectorDismissed()
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func dismiss() {
        RuntimeStorage.messagesVC?.messageInputBar.inputTextView.resignFirstResponder()
        RuntimeStorage.messagesVC?.messageInputBar.alpha = 0
        isPresenting = false
    }
    
    private func handleContactSelectorDismissed() {
        if let pair = selectedContactPair {
            guard let messagesVC = RuntimeStorage.messagesVC,
                  let recipientBar = messagesVC.recipientBar else { return }
            recipientBar.handleContactSelected(with: pair)
        } else if RuntimeStorage.wantsToInvite! {
            isPresenting = false
            Core.gcd.after(seconds: 2) {
                viewModel.presentShareSheet()
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

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Conversation */
public extension Conversation {
    static func empty() -> Conversation {
        return Conversation(identifier: ConversationID(key: "EMPTY",
                                                       hash: "EMPTY"),
                            messageIdentifiers: [],
                            messages: [],
                            lastModifiedDate: Date(),
                            participants: [])
    }
}

/* MARK: View */
extension View {
    @available(iOS 14, *)
    func navigationBar(backgroundColor: Color, titleColor: Color) -> some View {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(backgroundColor)
        
        let uiTitleColor = UIColor(titleColor)
        appearance.largeTitleTextAttributes = [.foregroundColor: uiTitleColor]
        appearance.titleTextAttributes = [.foregroundColor: uiTitleColor]
        
        if RuntimeStorage.navigationBarStandardAppearance == nil {
            RuntimeStorage.store(UINavigationBar.appearance().standardAppearance,
                                 as: .navigationBarStandardAppearance)
        }
        
        if RuntimeStorage.navgationBarScrollEdgeAppearance == nil,
           let scrollEdgeAppearance = UINavigationBar.appearance().scrollEdgeAppearance {
            RuntimeStorage.store(scrollEdgeAppearance,
                                 as: .navgationBarScrollEdgeAppearance)
        }
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        return self
    }
}
