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
import MessageKit

//==================================================//

/* MARK: - Top-level Variable Declarations */

//Other Declarations
public var conversations: [Conversation] = []
public var updated = false

//==================================================//

public struct ConversationsPageView: View {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    //Other Declarations
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
            //                        let conversationsToUse = conversations.count == 0 ? openConversations.sorted(by: { $0.messages.last?.sentDate ?? Date() > $1.messages.last?.sentDate ?? Date() }) : conversations.sorted(by: { $0.messages.last?.sentDate ?? Date() > $1.messages.last?.sentDate ?? Date() })
            
            let conversationsToUse = conversations.count == 0 ? openConversations.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate }) : conversations.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate })
            
            NavigationView {
                List {
                    ForEach(0..<conversationsToUse.count, id: \.self, content: { index in
                        let conversation = conversationsToUse[index]
                        
                        MessageCell(conversation: conversation)
                    })
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingPopover = true
                        }) {
                            Label("Compose", systemImage: "square.and.pencil")
                        }
                        .sheet(isPresented: $showingPopover) {
                            EmbeddedContactPickerView()
                                .onDisappear {
                                    viewModel.startConversation()
                                }
                            //.interactiveDismissDisabled(true)
                        }
                    }
                }
                .navigationBarTitle(translations["messages"]!.output)
            }
            .onAppear() {
                if !updated {
                    conversations = openConversations    
                }
                
                updated = false
            }
        case .failed(let errorDescriptor):
            Text(errorDescriptor)
        }
    }
}
