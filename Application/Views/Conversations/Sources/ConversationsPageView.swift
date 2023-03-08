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
    @State private var showingPopover = false
    
    // CGFloats
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
        case .loaded(let translations,
                     let conversations):
            loadedView(translations: translations,
                       conversations: conversations)
        case .failed(let exception):
            Text(exception.userFacingDescriptor)
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
            .sheet(isPresented: $showingPopover) {
                NewChatPageView(viewModel: NewChatPageViewModel(),
                                isPresenting: $showingPopover)
                .onAppear {
                    ContactNavigationRouter.currentlySelectedUser = nil
                }
                .onDisappear {
                    composeButtonEnabled = true
                    stateProvider.tappedDone = false
                    
                    AnalyticsService.logEvent(.dismissNewChatPage)
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
                showingPopover = true
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
        
        var preferenceActions = [AKAction(title: "Log Out", style: .default),
                                 AKAction(title: "Clear Caches", style: .default)]
        
        if Build.developerModeEnabled,
           let currentUser = RuntimeStorage.currentUser,
           currentUser.languageCode != "en" {
            let languageCode = currentUser.languageCode!
            let languageName = languageCode.languageName ?? languageCode.uppercased()
            
            let overrideOrRestore = AKCore.shared.languageCodeIsLocked ? "Restore Language to \(languageName)" : "Override Language Code to English"
            preferenceActions.append(AKAction(title: overrideOrRestore, style: .default))
        }
        
        var translationKeys: [AKTranslationOptionKey] = [.actions(indices: [0, 1, 3])]
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
                viewModel.confirmSignOut(viewRouter)
            case preferenceActions[1].identifier:
                viewModel.confirmClearCaches()
            case preferenceActions[2].identifier:
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
