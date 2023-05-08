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
import Translator

public struct ConversationsPageView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Booleans
    @State private var composeButtonEnabled = true
    @State private var hasRecordedInitialYOrigin = false
    @State private var settingsButtonEnabled = true
    @State private var shouldPulseComposeButton = false
    @State private var showingInviteLanguagePickerSheet = false
    @State private var showingNewChatSheet = false
    @State private var showingSettingsSheet = false
    
    // CGFloats
    @State private var animationAmount: CGFloat = 1.0
    @State private var currentYOrigin: CGFloat = 0.0
    @State private var initialYOrigin: CGFloat = 0.0
    
    // Other
    @StateObject public var viewModel: ConversationsPageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    @State private var forceAppearanceUpdate = UUID()
    @ObservedObject private var stateProvider = StateProvider.shared
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear { viewModel.load() }
        case .loading:
            ProgressView("" /*"Loading..."*/)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.encapsulatingViewBackgroundColor)
        case .loaded(let translations,
                     let conversations):
            ThemedView(onAppearanceChange: {
                guard !RuntimeStorage.isPresentingChat! else { return }
                viewModel.load(silent: true) { self.forceAppearanceUpdate = UUID() }
            }) {
                loadedView(translations: translations, conversations: conversations)
                    .onAppear { UIApplication.shared.overrideUserInterfaceStyle(ThemeService.currentTheme.style) }
            }
        case .failed(let exception):
            FailureView(exception: exception) { viewModel.load() }
        }
    }
    
    private func loadedView(translations: [String: Translator.Translation],
                            conversations: [Conversation]) -> some View {
        VStack {
            withUpdatedAppearance(NavigationView {
                listView(conversations: conversations.visibleForCurrentUser,
                         messagesTranslation: translations["messages"]!.output)
                .onFrameChange { frame in respondToListFrameChange(frame) }
            }.accentColor(.primaryAccentColor))
            .id(forceAppearanceUpdate)
            .sheet(isPresented: $showingNewChatSheet) { newChatSheet }
            .sheet(isPresented: $showingInviteLanguagePickerSheet) { inviteLanguagePickerSheet }
            .sheet(isPresented: $showingSettingsSheet) { settingsSheet }
        }
        .onChange(of: stateProvider.hasDisappeared, perform: { newValue in
            guard newValue else { return }
            viewModel.reloadIfNeeded()
            
            guard let previousYOrigin = RuntimeStorage.previousYOrigin,
                  previousYOrigin != 0,
                  initialYOrigin == previousYOrigin else {
                RuntimeStorage.topWindow?.isUserInteractionEnabled = true
                return
            }
            
            forceAppearanceUpdate = UUID()
            RuntimeStorage.topWindow?.isUserInteractionEnabled = true
        })
        .onChange(of: stateProvider.tappedSelectContactButton, perform: { newValue in
            guard newValue else { return }
            stateProvider.tappedSelectContactButton = false
        })
        .onChange(of: stateProvider.showNewChatPageForGrantedContactAccess, perform: { newValue in
            guard newValue else { return }
            showingNewChatSheet = true
        })
        .onChange(of: stateProvider.showingInviteLanguagePicker, perform: { newValue in
            guard newValue else { return }
            showingInviteLanguagePickerSheet = true
            stateProvider.showingInviteLanguagePicker = false
        })
        .onChange(of: stateProvider.currentUserLacksVisibleConversations, perform: { newValue in
            guard !newValue else { return }
            shouldPulseComposeButton = newValue
        })
        .onAppear {
            RuntimeStorage.store(#file, as: .currentFile)
            guard conversations.visibleForCurrentUser.count == 0 else {
                shouldPulseComposeButton = false
                return
            }
            
            shouldPulseComposeButton = true
            
            guard RuntimeStorage.isFirstLaunchFromSetup! else { return }
            RuntimeStorage.store(false, as: .isFirstLaunchFromSetup)
            Core.gcd.after(milliseconds: 1500) { showingNewChatSheet = true }
        }
        .navigationViewStyle(.stack)
    }
    
    private func withUpdatedAppearance(_ conversationsPageView: some View) -> some View {
        guard #available(iOS 16.0, *) else { return AnyView(conversationsPageView) }
        return AnyView(conversationsPageView.toolbarBackground(Color.navigationBarBackgroundColor, for: .navigationBar).scrollContentBackground(.hidden))
    }
    
    //==================================================//
    
    /* MARK: - Sheets */
    
    private var inviteLanguagePickerSheet: some View {
        LanguagePickerView(isPresenting: $showingInviteLanguagePickerSheet)
            .onAppear {
                Core.ui.setNavigationBarAppearance(backgroundColor: .navigationBarBackgroundColor,
                                                   titleColor: .navigationBarTitleColor)
            }
            .onDisappear {
                Core.ui.resetNavigationBarAppearance()
                guard RuntimeStorage.invitationLanguageCode != nil else { return }
                InviteService.composeInvitation()
            }
    }
    
    private var newChatSheet: some View {
        NewChatPageView(viewModel: NewChatPageViewModel(),
                        isPresenting: $showingNewChatSheet)
        .onAppear {
            ContactNavigationRouter.currentlySelectedUser = nil
        }
        .onDisappear {
            composeButtonEnabled = true
            stateProvider.tappedDone = false
            
            AnalyticsService.logEvent(.dismissNewChatPage)
        }
    }
    
    private var settingsSheet: some View {
        SettingsPageView(isPresenting: $showingSettingsSheet,
                         viewModel: SettingsPageViewModel(),
                         viewRouter: viewRouter)
        .onAppear {
            Core.ui.setNavigationBarAppearance(backgroundColor: .navigationBarBackgroundColor,
                                               titleColor: .navigationBarTitleColor)
        }
        .onDisappear {
            settingsButtonEnabled = true
            Core.ui.resetNavigationBarAppearance()
        }
    }
    
    //==================================================//
    
    /* MARK: - Toolbar Buttons */
    
    @ToolbarContentBuilder
    private var composeButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                showingNewChatSheet = true
                composeButtonEnabled = false
            }) {
                if shouldPulseComposeButton {
                    Label("Compose", systemImage: "square.and.pencil")
                        .foregroundColor(.primaryAccentColor)
                        .scaleEffect(animationAmount)
                        .animation(
                            .linear(duration: 0.4)
                            .delay(0.1)
                            .repeatForever(autoreverses: true),
                            value: animationAmount)
                        .onAppear {
                            animationAmount = 1.4
                        }
                } else {
                    Label("Compose", systemImage: "square.and.pencil")
                        .foregroundColor(.primaryAccentColor)
                }
            }
            .disabled(!composeButtonEnabled)
        }
    }
    
    @ToolbarContentBuilder
    private var settingsButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: {
                showingSettingsSheet = true
                settingsButtonEnabled = false
            }) {
                Label("Settings", systemImage: "gearshape")
                    .foregroundColor(.primaryAccentColor)
            }
            .disabled(!settingsButtonEnabled)
        }
    }
    
    //==================================================//
    
    /* MARK: - Other Views */
    
    private func listView(conversations: [Conversation],
                          messagesTranslation: String) -> some View {
        List {
            ForEach(0..<conversations.count, id: \.self, content: { index in
                ConversationCell(conversation: conversations[index])
                    .swipeActions(allowsFullSwipe: false, content: {
                        Button {
                            viewModel.deleteConversation(conversations[index])
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    })
                    .listRowBackground(Color.encapsulatingViewBackgroundColor)
            })
        }
        .listStyle(.plain)
        .navigationBarTitle(messagesTranslation)
        .navigationBarColor(backgroundColor: .navigationBarBackgroundColor,
                            titleColor: .navigationBarTitleColor)
        .background(Color.encapsulatingViewBackgroundColor)
        .refreshable {
            viewModel.load(silent: true)
        }
        .toolbar {
            settingsButton
            composeButton
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func respondToListFrameChange(_ frame: CGRect) {
        guard !RuntimeStorage.isPresentingChat! else { return }
        
        guard !hasRecordedInitialYOrigin else {
            currentYOrigin = frame.origin.y
            RuntimeStorage.store(currentYOrigin, as: .currentYOrigin)
            
            guard let previousYOrigin = RuntimeStorage.previousYOrigin,
                  previousYOrigin != currentYOrigin,
                  currentYOrigin == initialYOrigin else { return }
            RuntimeStorage.topWindow?.isUserInteractionEnabled = false
            Core.gcd.after(milliseconds: 500) {
                if !RuntimeStorage.isPresentingChat! {
                    self.forceAppearanceUpdate = UUID()
                }
                RuntimeStorage.topWindow?.isUserInteractionEnabled = true
            }
            RuntimeStorage.remove(.previousYOrigin)
            
            return
        }
        
        guard frame.origin.y != 0 else { return }
        initialYOrigin = frame.origin.y
        hasRecordedInitialYOrigin = true
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: - View */
private extension View {
    func onFrameChange(_ frameHandler: @escaping (CGRect)->(),
                       enabled isEnabled: Bool = true) -> some View {
        guard isEnabled else { return AnyView(self) }
        return AnyView(self.background(GeometryReader { (geometry: GeometryProxy) in
            Color.clear.beforeReturn { frameHandler(geometry.frame(in: .global)) }
        }))
    }
    
    private func beforeReturn(_ onBeforeReturn: ()->()) -> Self {
        onBeforeReturn()
        return self
    }
}
