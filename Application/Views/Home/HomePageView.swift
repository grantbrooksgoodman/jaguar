//
//  HomePageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 30/06/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import MessageKit

public struct HomePageView: View {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    //Other Declarations
    @StateObject public var viewModel: HomePageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear(perform: viewModel.load)
        case .loading:
            ProgressView("Loading...")
        case .loaded(let translations,
                     var conversations):
            NavigationView {
                List {
                    ForEach(0..<conversations.count, id: \.self, content: { index in
                        let conversationBinding = Binding(get: { conversations[index] },
                                                          set: { conversations[index] = $0 })
                        let conversation = conversations[index]
                        let cellTitle = ContactsServer.fetchContactName(forNumber: conversation.otherUser!.phoneNumber) ?? conversation.otherUser!.formattedPhoneNumber()
                        
                        let lastMessage = conversation.messages.last
                        
                        HStack {
                            ContactImageView(uiImage: ContactsServer.fetchContactThumbnail(forNumber: conversation.otherUser!.phoneNumber))
                            
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
                            promptForNumber()
                        }) {
                            Label("Compose", systemImage: "square.and.pencil")
                        }
                    }
                }
                .navigationBarTitle(translations["messages"]!.output)
            }
        case .failed(let errorDescriptor):
            Text(errorDescriptor)
        }
    }
    
    //==================================================//
    
    /* MARK: - Other Views */
    
    public struct ContactImageView: View {
        
        //==================================================//
        
        /* MARK: - Struct-level Variable Declarations */
        
        public var uiImage: UIImage?
        
        //==================================================//
        
        /* MARK: - View Body */
        
        public var body: some View {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .font(.system(size: 50))
                    .frame(width: 50, height: 50)
                    .cornerRadius(10)
                    .clipShape(Circle())
                    .padding(.top, 10)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 50))
                    .frame(width: 50, height: 50)
                    .cornerRadius(10)
                    .foregroundColor(Color.gray)
                    .padding(.top, 10)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Functions */
    
    public func promptForNumber() {
        let textFieldAlert = AKTextFieldAlert(message: "Enter a number to chat with.",
                                              actions: [AKAction(title: "Done", style: .preferred)],
                                              textFieldAttributes: [.keyboardType: UIKeyboardType.phonePad])
        
        textFieldAlert.present { (returnedString, actionID) in
            if actionID != -1 {
                guard let string = returnedString,
                      string.digits == string else {
                    let error = AKError("Invalid phone number.",
                                        metadata: [#file, #function, #line],
                                        isReportable: true)
                    
                    AKErrorAlert(message: "The phone number entered was invalid.",
                                 error: error,
                                 networkDependent: false).present()
                    return
                }
                
                self.findUser(withNumber: string)
            }
        }
    }
    
    public func findUser(withNumber: String) {
        UserSerializer.shared.findUser(byPhoneNumber: withNumber) { (returnedUser,
                                                                     errorDescriptor) in
            guard returnedUser != nil || errorDescriptor != nil else {
                log("An unknown error occurred.",
                    metadata: [#file, #function, #line])
                return
            }
            
            if let error = errorDescriptor {
                log(error,
                    metadata: [#file, #function, #line])
            } else if let user = returnedUser {
                self.createConversation(withUser: user)
            }
        }
    }
    
    public func createConversation(withUser: User) {
        ConversationSerializer.shared.createConversation(initialMessageIdentifier: "!",
                                                         participantIdentifiers: [currentUserID,
                                                                                  withUser.identifier]) { (returnedIdentifier, errorDescriptor) in
            guard returnedIdentifier != nil || errorDescriptor != nil else {
                log("An unknown error occurred.",
                    metadata: [#file, #function, #line])
                
                return
            }
            
            if let error = errorDescriptor {
                log(error, metadata: [#file, #function, #line])
            } else if let identifier = returnedIdentifier {
                print("new conversation with id: \(identifier)")
            }
        }
    }
}
