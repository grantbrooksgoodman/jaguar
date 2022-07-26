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
                        let cellTitle = getCellTitle(forUser: conversation.otherUser!)
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
                                    startConversation()
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
    
    //==================================================//
    
    /* MARK: - Functions */
    
    public func createConversation(withUser: User) {
        ConversationSerializer.shared.createConversation(initialMessageIdentifier: "!",
                                                         participantIdentifiers: [currentUserID,
                                                                                  withUser.identifier]) { (returnedIdentifier, errorDescriptor) in
            
            guard let identifier = returnedIdentifier else {
                Logger.log(errorDescriptor ?? "An unknown error occurred.",
                           metadata: [#file, #function, #line])
                return
            }
            
            currentUser!.deSerializeConversations { (returnedConversations,
                                                     errorDescriptor) in
                if let error = errorDescriptor {
                    Logger.log(error, metadata: [#file, #function, #line])
                } else if let deSerializedConversations = returnedConversations {
                    updated = true
                    conversations = deSerializedConversations
                    
                    for (index, conversation) in conversations.enumerated() {
                        conversation.setOtherUser { (errorDescriptor) in
                            Logger.log(errorDescriptor ?? "Set other user.",
                                       metadata: [#file, #function, #line])
                            if index == conversations.count - 1 {
                                viewModel.load()
                            }
                        }
                    }
                }
            }
            
            print("new conversation with id: \(identifier)")
        }
    }
    
    public func getCellTitle(forUser: User) -> String {
        let phoneNumber = forUser.phoneNumber!
        var cellTitle = phoneNumber.callingCodeFormatted(region: forUser.region)
        
        if let name = ContactsServer.fetchContactName(forNumber: phoneNumber) {
            cellTitle = "\(name.givenName) \(name.familyName)"
        }
        
        return cellTitle
    }
    
    public func startConversation() {
        guard let contact = selectedContact else {
            Logger.log("Contact selection was not processed.",
                       metadata: [#file, #function, #line])
            return
        }
        
        let dispatchGroup = DispatchGroup()
        var foundUser: User?
        
        for (index, phoneNumber) in contact.phoneNumbers.enumerated() {
            dispatchGroup.enter()
            
            #warning("ACCOUNT FOR NOT HAVING PREFIX CODE!!")
            UserSerializer.shared.findUser(byPhoneNumber: phoneNumber.value.stringValue.digits) { (returnedUser, errorDescriptor) in
                dispatchGroup.leave()
                
                guard let user = returnedUser else {
                    if index == contact.phoneNumbers.count - 1 {
                        let noUserString = "No user exists with the provided phone number."
                        
                        Logger.log(errorDescriptor ?? "An unknown error occurred.",
                                   with: errorDescriptor == noUserString ? .none : .errorAlert,
                                   metadata: [#file, #function, #line])
                        
                        if errorDescriptor == noUserString {
                            let alert = AKAlert(message: "\(noUserString)\n\nWould you like to send them an invite to sign up?",
                                                actions: [AKAction(title: "Send Invite",
                                                                   style: .preferred)])
                            alert.present { (actionID) in
                                if actionID != -1 {
                                    print("wants to invite")
                                }
                            }
                        }
                    }
                    
                    return
                }
                
                foundUser = user
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if let user = foundUser {
                guard user.phoneNumber.digits != currentUser!.phoneNumber.digits else {
                    Logger.log("Cannot start a conversation with yourself.",
                               with: .errorAlert,
                               metadata: [#file, #function, #line])
                    return
                }
                
                currentUser!.deSerializeConversations(completion: { (returnedConversations,
                                                                     errorDescriptor) in
                    guard let conversations = returnedConversations else {
                        Logger.log(errorDescriptor ?? "An unknown error occurred.",
                                   metadata: [#file, #function, #line])
                        return
                    }
                    
                    if conversations.contains(where: { $0.participantIdentifiers.contains(user.identifier) }) {
                        Logger.log("Conversation with this user alreasdy exists.",
                                   with: .errorAlert,
                                   metadata: [#file, #function, #line])
                    } else {
                        self.createConversation(withUser: user)
                    }
                })
            }
        }
    }
}
