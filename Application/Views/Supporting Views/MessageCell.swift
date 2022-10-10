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
    
    /* MARK: - Properties */
    
    public var conversation: Conversation
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        var mutableConversation = conversation
        let conversationBinding = Binding(get: { mutableConversation },
                                          set: { mutableConversation = $0 })
        
        let cellTitle = getCellTitle(forUser: conversation.otherUser!)
        let lastMessage = conversation.messages.last
        let lastMessageFromOtherUser = conversation.messages.filter({ $0.fromAccountIdentifier != RuntimeStorage.currentUserID! }).last
        
        let contactImage = ContactService.fetchContactThumbnail(forNumber: conversation.otherUser!.phoneNumber) ?? nil
        
        HStack {
            //Use alignment guide here
            if let last = lastMessageFromOtherUser,
               last.readDate == nil {
                Circle()
                    .foregroundColor(.blue)
                    .frame(width: 10, height: 10, alignment: .center)
                    .offset(x: -4,
                            y: 7)
            }
            
            ContactImageView(uiImage: contactImage == nil ? nil : contactImage == UIImage() ? nil : contactImage)
            
            VStack(alignment: .leading) {
                HStack {
                    Text(cellTitle)
                        .bold()
                        .padding(.bottom, 0.01)
                    
                    Rectangle()
                    //                        .overlay(Image(uiImage: getRegionImage())
                    //                            .resizable()
                    //                            .scaledToFit())
                        .overlay(Text(conversation.otherUser!.languageCode.uppercased())
                            .font(Font.system(size: 12))
                            .foregroundColor(Color.white)
                            .shadow(color: .black, radius: 20)
                            .frame(width: 20,
                                   height: 10,
                                   alignment: .center)
                                .opacity(0.8))
                        .frame(maxWidth: 20, maxHeight: 20)
                        .foregroundColor(Color.gray)
                        .cornerRadius(3, corners: [.allCorners])
                    
                    Image(uiImage: getRegionImage())
                        .resizable()
                        .frame(width: 20,
                               height: 10,
                               alignment: .center)
                }
                
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
        
        if forMessage.fromAccountIdentifier == RuntimeStorage.currentUserID! {
            textToUse = forMessage.translation.input.value()
        } else {
            textToUse = forMessage.translation.output
        }
        
        return textToUse
    }
    
    private func getCellTitle(forUser: User) -> String {
        let phoneNumber = forUser.phoneNumber!
        var cellTitle = phoneNumber.callingCodeFormatted(region: forUser.region)
        
        if let name = ContactService.fetchContactName(forNumber: phoneNumber),
           name != ("", "") {
            cellTitle = "\(name.givenName) \(name.familyName)"
        }
        
        return cellTitle
    }
    
    private func getRegionImage() -> UIImage {
        if let imageFromLanguageCode = UIImage(named: "\(conversation.otherUser!.languageCode.lowercased()).png") {
            return imageFromLanguageCode
        }
        
        if let imageFromRegion = UIImage(named: "\(conversation.otherUser!.region.lowercased()).png") {
            return imageFromRegion
        }
        
        return UIImage()
    }
}

private struct RoundedCorner: Shape {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public var radius: CGFloat = .infinity
    public var corners: UIRectCorner = .allCorners
    
    //==================================================//
    
    /* MARK: - Functions */
    
    public func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        
        return Path(path.cgPath)
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: - View */
private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
