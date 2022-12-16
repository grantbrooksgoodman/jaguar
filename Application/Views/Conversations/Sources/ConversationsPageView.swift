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
import FirebaseDatabase
import MessageKit
import Translator

public struct ConversationsPageView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Booleans
    @State private var composeButtonEnabled = true
    @State private var settingsButtonEnabled = true
    @State private var showingPopover = false
    
    // Other
    @StateObject public var viewModel: ConversationsPageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    @ObservedObject private var stateProvider = StateProvider.shared
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear { viewModel.load() }
        case .loading:
            ProgressView("" /*"Loading..."*/)
        case .loaded(let translations):
            loadedView(translations: translations)
        case .failed(let exception):
            Text(exception.userFacingDescriptor)
        }
    }
    
    private func loadedView(translations: [String: Translator.Translation]) -> some View {
        VStack {
            NavigationView {
                listView(conversations: RuntimeStorage.currentUser?.openConversations?.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate }).unique() ?? [],
                         messagesTranslation: translations["messages"]!.output)
            }
            .sheet(isPresented: $showingPopover) {
                NewChatPageView(viewModel: NewChatPageViewModel(),
                                isPresenting: $showingPopover)
                .onAppear {
                    ContactNavigationRouter.currentlySelectedUser = nil
                }
                .onDisappear {
                    composeButtonEnabled = true
                    stateProvider.tappedDone = false
                }
            }
        }
        .onChange(of: stateProvider.hasDisappeared, perform: { newValue in
            guard newValue else { return }
            viewModel.reloadIfNeeded()
        })
        .onChange(of: stateProvider.tappedSelectContactButton, perform: { newValue in
            guard newValue else { return }
            stateProvider.tappedSelectContactButton = false
        })
        .onAppear { RuntimeStorage.store(#file, as: .currentFile) }
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
            })
            .onDelete(perform: viewModel.deleteConversation(at:))
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
        
        let preferenceActions = [AKAction(title: "Log Out", style: .default),
                                 AKAction(title: "Destroy Database", style: .destructive)]
        
        let actionSheet = AKActionSheet(message: "Preferences",
                                        actions: preferenceActions)
        
        actionSheet.present { actionID in
            settingsButtonEnabled = true
            
            switch actionID {
            case preferenceActions[0].identifier:
                viewModel.confirmSignOut(viewRouter)
            case preferenceActions[1].identifier:
                viewModel.confirmTrashDatabase()
            default:
                return
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
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
