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
            var conversationsToUse = conversations.count == 0 ? openConversations.sorted(by: { $0.lastModifiedDate < $1.lastModifiedDate }) : conversations.sorted(by: { $0.lastModifiedDate < $1.lastModifiedDate })
            
            NavigationView {
                List {
                    ForEach(0..<conversationsToUse.count, id: \.self, content: { index in
                        let conversationBinding = Binding(get: { conversationsToUse[index] },
                                                          set: { conversationsToUse[index] = $0 })
                        let conversation = conversationsToUse[index]
                        let phoneNumber = conversation.otherUser!.phoneNumber!
                        
                        #warning("HANDLE REGION HERE")
                        let cellTitle = viewModel.getCellTitle(forUser: conversation.otherUser!)
                        let lastMessage = conversation.messages.last
                        
                        HStack {
                            ContactImageView(uiImage: ContactsServer.fetchContactThumbnail(forNumber: phoneNumber))
                            
                            VStack(alignment: .leading) {
                                Text(cellTitle)
                                    .bold()
                                    .padding(.bottom, 0.01)
                                
                                Text(lastMessage?.translation.output ?? "")
                                    .foregroundColor(.gray)
                                    .font(Font.system(size: 12))
                                    //.padding(.top, 0.01)
                                    .lineLimit(2)
                            }
                            .padding(.top, 5)
                            
                            NavigationLink("",
                                           destination: ChatPageView(conversation:
                                                                        conversationBinding)
                                            .navigationTitle(cellTitle)
                                            .navigationBarTitleDisplayMode(.inline))
                                .frame(width: 0)
                        }
                        .padding(.bottom, 10)
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
