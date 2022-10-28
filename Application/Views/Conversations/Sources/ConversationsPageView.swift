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
            ProgressView("" /*"Loading..."*/) /* .onAppear {
                                               ConversationTestingSerializer.createRandomConversation { exception in
                                               if let exception = exception {
                                               Logger.log(exception)
                                               } else {
                                               Logger.log("Successfully created random conversation!",
                                               metadata: [#file, #function, #line])
                                               }
                                               }
                                               } */
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
                self.confirmTrashDatabase()
            })
            .onAppear { RuntimeStorage.store(#file, as: .currentFile) }
        case .failed(let exception):
            Text(exception.userFacingDescriptor)
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func confirmTrashDatabase() {
        AKConfirmationAlert(title: "Destroy Database",
                            message: "Are you sure you'd like to trash the database? This operation cannot be undone.",
                            confirmationStyle: .destructivePreferred).present { didConfirm in
            if didConfirm == 1 {
                AKConfirmationAlert(title: "Are you sure?",
                                    message: "ALL CONVERSATIONS FOR ALL USERS WILL BE DELETED!",
                                    cancelConfirmTitles: (cancel: nil, confirm: "Yes, I'm sure"),
                                    confirmationStyle: .destructivePreferred).present { confirmed in
                    if confirmed == 1 {
                        trashDatabase()
                    }
                }
            }
        }
    }
    
    private func removeConversationsForAllUsers(completion: @escaping(_ exception: Exception?) -> Void) {
        Database.database().reference().child("/allUsers").observeSingleEvent(of: .value) { (returnedSnapshot) in
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  let data = snapshot as? [String: Any] else {
                let exception = Exception("Couldn't get user list.",
                                          metadata: [#file, #function, #line])
                
                Logger.log(exception,
                           with: .errorAlert)
                completion(exception)
                
                return
            }
            
            var exceptions = [Exception]()
            for (index, identifier) in Array(data.keys).enumerated() {
                GeneralSerializer.setValue(onKey: "/allUsers/\(identifier)/openConversations",
                                           withData: ["!"]) { returnedError in
                    if let error = returnedError {
                        let exception = Exception(error, metadata: [#file, #function, #line])
                        
                        Logger.log(exception)
                        exceptions.append(exception)
                    }
                }
                
                if index == Array(data.keys).count - 1 {
                    completion(exceptions.compiledException)
                }
            }
        }
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
    
    private func trashDatabase() {
        removeConversationsForAllUsers { exception in
            guard exception == nil else {
                AKErrorAlert(error: exception!.asAkError()).present()
                return
            }
            
            let keys = ["Conversations", "Messages"]
            
            var exceptions = [Exception]()
            for (index, key) in keys.enumerated() {
                GeneralSerializer.setValue(onKey: "/all\(key)",
                                           withData: NSNull()) { returnedError in
                    if let error = returnedError {
                        exceptions.append(Exception(error, metadata: [#file, #function, #line]))
                    }
                }
                
                if index == keys.count - 1 {
                    guard exceptions.count == 0 else {
                        AKErrorAlert(error: exceptions.compiledException!.asAkError()).present()
                        return
                    }
                    
                    AKAlert(message: "Successfully trashed database.",
                            cancelButtonTitle: "OK").present { _ in
                        RuntimeStorage.remove(.conversations)
                        ConversationArchiver.clearArchive()
                        viewModel.load()
                    }
                }
            }
        }
    }
}
