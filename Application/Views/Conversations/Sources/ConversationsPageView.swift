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
    @State private var showingInviteLanguagePickerSheet = false
    @State private var showingNewChatSheet = false
    
    // CGFloats
    @State private var currentYOrigin: CGFloat = 0.0
    @State private var initialYOrigin: CGFloat = 0.0
    
    // Other
    @StateObject public var viewModel: ConversationsPageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    @Environment(\.colorScheme) private var colorScheme
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
        case .loaded(let translations,
                     let conversations):
            loadedView(translations: translations,
                       conversations: conversations)
        case .failed(let exception):
            FailureView(exception: exception) { viewModel.load() }
        }
    }
    
    private func loadedView(translations: [String: Translator.Translation],
                            conversations: [Conversation]) -> some View {
        VStack {
            NavigationView {
                listView(conversations: conversations.visibleForCurrentUser,
                         messagesTranslation: translations["messages"]!.output)
                .onFrameChange { frame in respondToListFrameChange(frame) }
            }
            .id(forceAppearanceUpdate)
            .sheet(isPresented: $showingNewChatSheet) {
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
            .sheet(isPresented: $showingInviteLanguagePickerSheet) {
                LanguagePickerView(isPresenting: $showingInviteLanguagePickerSheet)
                    .onAppear {
                        let backgroundColor = UIColor(hex: colorScheme == .dark ? 0x2A2A2C : 0xF8F8F8)
                        let titleColor: UIColor = colorScheme == .dark ? .white : .black
                        Core.ui.setNavigationBarAppearance(backgroundColor: backgroundColor, titleColor: titleColor)
                    }
                    .onDisappear {
                        Core.ui.resetNavigationBarAppearance()
                        guard RuntimeStorage.invitationLanguageCode != nil else { return }
                        InviteService.composeInvitation()
                    }
            }
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
        .onAppear {
            RuntimeStorage.store(#file, as: .currentFile)
        }
        .navigationViewStyle(.stack)
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
                Label("Compose", systemImage: "square.and.pencil")
            }
            .disabled(!composeButtonEnabled)
        }
    }
    
    @ToolbarContentBuilder
    private func doneButton(_ translation: String) -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                doneButtonAction()
            }) {
                Text(translation)
                    .font(Font.body.bold())
            }
        }
    }
    
    @ToolbarContentBuilder
    private var settingsButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: {
                settingsButtonAction()
            }) {
                Label("Settings", systemImage: "gearshape")
            }
            .disabled(!settingsButtonEnabled)
        }
    }
    
    //==================================================//
    
    /* MARK: - Other Views */
    
    private var appearanceBasedBackgroundColor: some View {
        guard colorScheme == .dark else {
            return Color(uiColor: UIColor(hex: 0xF8F8F8))
        }
        
        return Color(uiColor: UIColor(hex: 0x2A2A2C))
    }
    
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
            })
        }
        .listStyle(PlainListStyle())
        .navigationBarTitle(messagesTranslation)
        .refreshable {
            viewModel.load(silent: true)
        }
        .toolbar {
            settingsButton
            composeButton
        }
    }
    
    //==================================================//
    
    /* MARK: - Toolbar Button Actions */
    
    private func doneButtonAction() {
        guard let isSendingMessage = RuntimeStorage.isSendingMessage,
              !isSendingMessage else {
            Core.gcd.after(milliseconds: 500) {
                self.doneButtonAction()
            }
            return
        }
        
        RuntimeStorage.remove(.isSendingMessage)
    }
    
    private func settingsButtonAction() {
        settingsButtonEnabled = false
        
        var preferenceActions = [AKAction(title: "Clear Caches", style: .default),
                                 AKAction(title: LocalizedString.sendFeedback, style: .default),
                                 AKAction(title: "Log Out", style: .destructive)]
        
        if Build.developerModeEnabled,
           let currentUser = RuntimeStorage.currentUser,
           currentUser.languageCode != "en" {
            let languageCode = currentUser.languageCode!
            let languageName = languageCode.languageName ?? languageCode.uppercased()
            
            let overrideOrRestore = AKCore.shared.languageCodeIsLocked ? "Restore Language to \(languageName)" : "Override Language Code to English"
            preferenceActions.append(AKAction(title: overrideOrRestore, style: .default))
        }
        
        var translationKeys: [AKTranslationOptionKey] = [.actions(indices: [0, 2])]
        var message = "Preferences"
        
        if Build.developerModeEnabled {
            let user = RuntimeStorage.currentUser!
            
            let regionTitle = RegionDetailServer.getRegionTitle(forCallingCode: user.callingCode)
            
            let runtimeCode = RuntimeStorage.languageCode!
            let appLanguageName = runtimeCode.languageName ?? runtimeCode.uppercased()
            
            let userLanguageName = user.languageCode.languageName ?? user.languageCode.uppercased()
            
            message = "\(user.cellTitle)\n\nEnvironment: \(GeneralSerializer.environment.description)\n\nApp Language: \(appLanguageName)\nUser Language: \(userLanguageName)\n\nRegion: \(regionTitle)"
        } else {
            translationKeys.append(.title)
        }
        
        let actionSheet = AKActionSheet(message: message,
                                        actions: preferenceActions,
                                        shouldTranslate: translationKeys)
        
        actionSheet.present { actionID in
            settingsButtonEnabled = true
            
            guard actionID != -1 else { return }
            
            switch actionID {
            case preferenceActions[0].identifier:
                viewModel.confirmClearCaches()
            case preferenceActions[1].identifier:
                BuildInfoOverlayViewModel().presentSendFeedbackActionSheet()
            case preferenceActions[2].identifier:
                viewModel.confirmSignOut(viewRouter)
            case preferenceActions[3].identifier:
                viewModel.overrideLanguageCode()
            default:
                return
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func respondToListFrameChange(_ frame: CGRect) {
        guard !hasRecordedInitialYOrigin else {
            currentYOrigin = frame.origin.y
            RuntimeStorage.store(currentYOrigin, as: .currentYOrigin)
            
            guard let previousYOrigin = RuntimeStorage.previousYOrigin,
                  previousYOrigin != currentYOrigin,
                  currentYOrigin == initialYOrigin else { return }
            RuntimeStorage.topWindow?.isUserInteractionEnabled = false
            Core.gcd.after(milliseconds: 500) {
                self.forceAppearanceUpdate = UUID()
                RuntimeStorage.topWindow?.isUserInteractionEnabled = true
            }
            RuntimeStorage.remove(.previousYOrigin)
            
            return
        }
        
        guard frame.origin.y != 0 else { return }
        initialYOrigin = frame.origin.y
        hasRecordedInitialYOrigin = true
    }
    
    private func testExceptionDepth() {
        let totalToGenerate = 10
        
        var exceptions = [Exception]()
        while exceptions.count < totalToGenerate {
            let randomAction = Int().random(min: 0, max: 3)
            
            var randomException = Exception(SentenceGenerator.generateSentence(wordCount: 5),
                                            isReportable: randomAction % 2 == 0,
                                            extraParams: ["index": "nil"],
                                            metadata: [#file, #function, Int().random(min: 0, max: 100)])
            
            switch randomAction {
            case 1:
                guard !exceptions.isEmpty else { continue }
                let randomIndex = Int().random(min: 0, max: exceptions.count - 1)
                
                var randomElement = exceptions[randomIndex]
                randomElement = randomElement.appending(underlyingException: randomException)
                
                exceptions.remove(at: randomIndex)
                exceptions.insert(randomElement, at: randomIndex)
            case 2:
                guard !exceptions.isEmpty else { continue }
                let randomIndex = Int().random(min: 0, max: exceptions.count - 1)
                
                let randomElement = exceptions[randomIndex]
                randomException = randomException.appending(underlyingException: randomElement).appending(underlyingException: randomException)
                
                exceptions.append(randomException)
            case 3:
                for var exception in exceptions {
                    exception = exception.appending(underlyingException: randomException).appending(underlyingException: exception)
                }
            default: /*0*/
                exceptions.append(randomException)
            }
        }
        
        let compiledException = exceptions.compiledException
        
        guard let compiledException = compiledException else { return }
        let underlyingExceptions = compiledException.allUnderlyingExceptions()
        
        print("Total desired: \(totalToGenerate)\nTotal exceptions generated: \(exceptions.count)\nAll underlying exceptions result: \(underlyingExceptions.count)")
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
