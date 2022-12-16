//
//  ConversationCell.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import AlertKit

public struct ConversationCell: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public var conversation: Conversation
    
    @Environment(\.colorScheme) private var colorScheme
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        if RuntimeStorage.currentUserID == nil ||
            RuntimeStorage.currentUser == nil ||
            conversation.otherUser == nil {
            Text("Required variables not set.")
        } else {
            bodyView()
        }
    }
    
    public func bodyView() -> some View {
        var mutableConversation = conversation
        let conversationBinding = Binding(get: { mutableConversation },
                                          set: { mutableConversation = $0 })
        
        let cellTitle = conversation.otherUser!.cellTitle
        let lastMessage = conversation.sortedFilteredMessages().last
        let lastMessageFromOtherUser = conversation.sortedFilteredMessages().filter({ $0.fromAccountIdentifier != RuntimeStorage.currentUserID! }).last
        
        let contactImage = ContactService.fetchContactThumbnail(forNumber: conversation.otherUser!.phoneNumber) ?? nil
        
        return NavigationLink(destination: chatPageView(conversation: conversationBinding,
                                                        title: cellTitle)) {
            HStack {
                Circle()
                    .foregroundColor(.blue)
                    .frame(width: 10, height: 10, alignment: .center)
                    .offset(x: -10,
                            y: 7)
                    .opacity(lastMessageFromOtherUser == nil ? 0 : lastMessageFromOtherUser!.readDate == nil ? 1 : 0)
                    .padding(.trailing, -15)
                
                AvatarImageView(uiImage: contactImage == nil ? nil : contactImage == UIImage() ? nil : contactImage)
                
                ZStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(cellTitle)
                                .bold()
                                .padding(.bottom, 0.01)
                            
                            Rectangle()
                                .overlay(dualIdentifierBadge, alignment: .center)
                                .frame(maxWidth: 50, maxHeight: 20)
                                .foregroundColor(Color(uiColor: UIColor(hex: colorScheme == .dark ? 0x27252A : 0xE5E5EA)))
                                .cornerRadius(3, corners: [.allCorners])
                        }
                        
                        let textToUse = lastMessage == nil ? "" : getCellSubtitle(forMessage: lastMessage!)
                        
                        Text(textToUse)
                            .foregroundColor(.gray)
                            .font(Font.system(size: 12))
                            .lineLimit(2)
                    }
                    .padding(.top, 5)
                }
            }
            .padding(.bottom, 8)
        }
    }
    
    //==================================================//
    
    /* MARK: - Supporting Views */
    
    public func chatPageView(conversation: Binding<Conversation>,
                             title: String) -> some View {
        ChatPageView(conversation: conversation)
            .onAppear {
                // #warning("This is buggy and doesn't seem to always work.")
                var conversations = [Conversation]()
                conversations.append(contentsOf: RuntimeStorage.currentUser!.openConversations ?? [])
                
                RuntimeStorage.store(conversations,
                                     as: .previousConversations)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                RuntimeStorage.messagesVC?.resignFirstResponder()
            }
    }
    
    public var dualIdentifierBadge: some View {
        Button {
            let otherUser = conversation.otherUser!
            let message = getLanguageAndRegionString(languageCode: otherUser.languageCode!,
                                                     regionCode: otherUser.region!)
            AKAlert(title: otherUser.cellTitle,
                    message: message,
                    cancelButtonTitle: "OK",
                    shouldTranslate: [.message, .cancelButtonTitle]).present()
        } label: {
            HStack(alignment: .center, spacing: 2) {
                Text(conversation.otherUser!.languageCode.uppercased())
                    .font(Font.system(size: 13).bold())
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                    .shadow(color: .black, radius: 20)
                    .frame(width: 20,
                           height: 10,
                           alignment: .center)
                    .opacity(0.8)
                
                Image(uiImage: getRegionImage())
                    .resizable()
                    .frame(width: 20,
                           height: 10,
                           alignment: .center)
                    .cornerRadius(2, corners: [.allCorners])
            }
        }
        .buttonStyle(HighPriorityButtonStyle())
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
    
    private func getLanguageAndRegionString(languageCode: String,
                                            regionCode: String) -> String {
        guard let languageCodeDictionary = RuntimeStorage.languageCodeDictionary else { return "" }
        
        let localizedRegionName = RegionDetailServer.getLocalizedRegionString(forRegionCode: regionCode)
        
        let code = languageCode == "ua" ? "uk" : languageCode
        guard var localizedLanguageName = languageCodeDictionary[code] else { return "" }
        localizedLanguageName = localizedLanguageName.components(separatedBy: " (")[0].trimmingTrailingWhitespace
        
        return "Region*:* \(localizedRegionName)\nLanguage*:* \(localizedLanguageName)"
    }
    
    private func getRegionImage() -> UIImage {
        if let imageFromRegion = UIImage(named: "\(conversation.otherUser!.region.lowercased()).png") {
            return imageFromRegion
        }
        
        if let imageFromLanguageCode = UIImage(named: "\(conversation.otherUser!.languageCode.lowercased()).png") {
            return imageFromLanguageCode
        }
        
        return UIImage()
    }
}

private struct HighPriorityButtonStyle: PrimitiveButtonStyle {
    private struct ButtonView: View {
        
        //==================================================//
        
        /* MARK: - Properties */
        
        @State var pressed = false
        let configuration: PrimitiveButtonStyle.Configuration
        
        //==================================================//
        
        /* MARK: - View Body */
        
        var body: some View {
            let gesture = DragGesture(minimumDistance: 0)
                .onChanged { _ in self.pressed = true }
                .onEnded { value in
                    self.pressed = false
                    if value.translation.width < 10 && value.translation.height < 10 {
                        self.configuration.trigger()
                    }
                }
            
            return configuration.label
                .opacity(self.pressed ? 0.5 : 1.0)
                .highPriorityGesture(gesture)
        }
    }
    
    //==================================================//
    
    /* MARK: - Functions */
    
    func makeBody(configuration: PrimitiveButtonStyle.Configuration) -> some View {
        ButtonView(configuration: configuration)
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