//
//  MessageCell.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

public struct MessageCell: View {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    public var conversation: Conversation
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        var mutableConversation = conversation
        let conversationBinding = Binding(get: { mutableConversation },
                                          set: { mutableConversation = $0 })
        
        let cellTitle = getCellTitle(forUser: conversation.otherUser!)
        let lastMessage = conversation.messages.last
        
        HStack {
            ContactImageView(uiImage: ContactsServer.fetchContactThumbnail(forNumber: conversation.otherUser!.phoneNumber))
            
            VStack(alignment: .leading) {
                Text(cellTitle)
                    .bold()
                    .padding(.bottom, 0.01)
                
                let textToUse = lastMessage == nil ? "" : getCellSubtitle(forMessage: lastMessage!)
                
                Text(textToUse)
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
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func getCellSubtitle(forMessage: Message) -> String {
        var textToUse = ""
        
        if forMessage.fromAccountIdentifier == currentUserID {
            textToUse = forMessage.translation.input.value()
        } else {
            textToUse = forMessage.translation.output
        }
        
        return textToUse
    }
    
    private func getCellTitle(forUser: User) -> String {
        let phoneNumber = forUser.phoneNumber!
        var cellTitle = phoneNumber.callingCodeFormatted(region: forUser.region)
        
        if let name = ContactsServer.fetchContactName(forNumber: phoneNumber) {
            cellTitle = "\(name.givenName) \(name.familyName)"
        }
        
        return cellTitle
    }
}
