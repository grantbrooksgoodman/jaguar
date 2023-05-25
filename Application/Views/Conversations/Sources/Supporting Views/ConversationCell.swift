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
import Translator

public struct ConversationCell: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public var conversation: Conversation
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var presentingAlert = false
    
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
        
        let lastMessage = conversation.messages.filteredAndSorted.last
        let lastMessageFromOtherUser = conversation.messages.filteredAndSorted.filter({ $0.fromAccountIdentifier != RuntimeStorage.currentUserID! }).last
        
        var isUnread = false
        if let lastMessageFromOtherUser,
           lastMessageFromOtherUser.readDate == nil {
            isUnread = true
        }
        
        let cellTitle = conversation.otherUser!.cellTitle
        let contactImage = cellTitle.hasPrefix("+") ? nil : (ContactService.fetchContactThumbnail(forUser: conversation.otherUser!) ?? nil)
        
        return withContextMenu(ZStack {
            NavigationLink(destination: chatPageView(conversation: conversationBinding,
                                                     title: cellTitle)) {
                EmptyView()
            }.buttonStyle(PlainButtonStyle())
                .frame(width: 0)
                .opacity(0)
            
            cellView(isUnread: isUnread,
                     contactImage: contactImage,
                     userTitle: cellTitle,
                     lastMessage: lastMessage)
        }, conversationBinding: conversationBinding, navigationTitle: cellTitle)
    }
    
    //==================================================//
    
    /* MARK: - Supporting Views */
    
    private func cellView(isUnread: Bool,
                          contactImage: UIImage?,
                          userTitle: String,
                          lastMessage: Message?) -> some View {
        Group {
            HStack {
                Circle()
                    .foregroundColor(.blue)
                    .frame(width: 10, height: 10, alignment: .center)
                    .offset(x: -10,
                            y: 7)
                    .opacity(isUnread ? 1 : 0)
                    .padding(.trailing, -15)
                
                AvatarImageView(uiImage: contactImage == nil ? nil : contactImage == UIImage() ? nil : contactImage)
                
                ZStack {
                    VStack(alignment: .leading) {
                        HStack {
                            HStack {
                                Text(userTitle)
                                    .bold()
                                    .padding(.bottom, 0.01)
                                    .foregroundColor(.titleTextColor)
                                    .font(.system(size: 500))
                                    .minimumScaleFactor(0.01)
                                
                                Rectangle()
                                    .overlay(dualIdentifierBadge, alignment: .center)
                                    .frame(maxWidth: 50, maxHeight: 20)
                                    .foregroundColor(Color(uiColor: UIColor(hex: colorScheme == .dark ? 0x27252A : 0xE5E5EA)))
                                    .cornerRadius(3, corners: [.allCorners])
                            }
                            
                            Spacer()
                            
                            HStack(alignment: .center, spacing: 0) {
                                Text(lastMessage?.sentDate.formattedString() ?? "12:00")
                                    .font(.system(size: 14))
                                    .foregroundColor(.subtitleTextColor)
                                    .padding(.trailing, 6)
                                
                                let colorToUse = ColorProvider.shared.interfaceStyle == .dark || ThemeService.currentTheme.style == .dark ? UIColor.subtitleTextColor.darker(by: 10)! : UIColor.subtitleTextColor.lighter(by: 30)!
                                
                                Image(systemName: "chevron.forward")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(uiColor: colorToUse))
                            }
                        }
                        
                        let textToUse = lastMessage == nil ? "" : getCellSubtitle(forMessage: lastMessage!)
                        
                        Text(textToUse)
                            .foregroundColor(Color(uiColor: .subtitleTextColor.lighter(by: 6)!))
                            .font(Font.system(size: 14))
                            .lineLimit(2, reservesSpace: true)
                            .offset(x: 1.5, y: -3)
                    }
                }
            }
        }
    }
    
    private func chatPageView(conversation: Binding<Conversation>,
                              title: String) -> some View {
        ChatPageView(conversation: conversation)
            .onAppear {
                guard let conversations = RuntimeStorage.currentUser?.openConversations else { return }
                UserDefaults.standard.set(conversations.hashes(), forKey: "previousHashes")
                
                AnalyticsService.logEvent(.accessChat,
                                          with: ["conversationIdKey": conversation.wrappedValue.identifier.key!])
                RuntimeStorage.store(RuntimeStorage.currentYOrigin ?? 0, as: .previousYOrigin)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarColor(backgroundColor: .navigationBarBackgroundColor,
                                titleColor: .navigationBarTitleColor)
            .background(ThemeService.currentTheme != AppThemes.default ? .navigationBarBackgroundColor : Color.clear)
            .toolbarBackground(Color.navigationBarBackgroundColor, for: .navigationBar)
            .onDisappear {
                RuntimeStorage.messagesVC?.resignFirstResponder()
                Core.ui.resetNavigationBarAppearance()
            }
    }
    
    private var dualIdentifierBadge: some View {
        Button {
            let otherUser = conversation.otherUser!
            let message = getLanguageAndRegionString(languageCode: otherUser.languageCode!,
                                                     regionCode: otherUser.region!)
            
            guard Build.developerModeEnabled else {
                presentingAlert = true
                AKAlert(title: otherUser.cellTitle,
                        message: message,
                        cancelButtonTitle: "OK",
                        shouldTranslate: [.message]).present { _ in
                    presentingAlert = false
                }
                return
            }
            
            let userID = otherUser.identifier!
            presentingAlert = true
            
            var title = otherUser.cellTitle
            let formattedNumber = otherUser.compiledPhoneNumber.phoneNumberFormatted
            if formattedNumber != title {
                title = "\(title)\n(\(formattedNumber))"
            }
            
            AKAlert(title: title,
                    message: message,
                    actions: [AKAction(title: "Set to Current User", style: .preferred)],
                    shouldTranslate: [.message]).present { actionID in
                presentingAlert = false
                guard actionID != -1 else { return }
                
                UserDefaults.reset()
                ContactArchiver.clearArchive()
                ContactService.clearCache()
                ConversationArchiver.clearArchive()
                RecognitionService.clearCache()
                RegionDetailServer.clearCache()
                TranslationArchiver.clearArchive()
                
                RuntimeStorage.remove(.currentMessageSlice)
                RuntimeStorage.remove(.currentUser)
                RuntimeStorage.remove(.globalConversation)
                RuntimeStorage.store([], as: .archivedLocalUserHashes)
                RuntimeStorage.store([], as: .archivedServerUserHashes)
                RuntimeStorage.store([], as: .contactPairs)
                RuntimeStorage.store(0, as: .messageOffset)
                
                UserDefaults.standard.set(userID, forKey: "currentUserID")
                RuntimeStorage.store(userID, as: .currentUserID)
                
                RuntimeStorage.conversationsPageViewModel?.load()
            }
        } label: {
            HStack(alignment: .center, spacing: 2) {
                Text(conversation.otherUser!.languageCode.uppercased())
                    .font(Font.system(size: 13).bold())
                    .foregroundColor(.titleTextColor)
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
        .disabled(presentingAlert)
    }
    
    private func withContextMenu(_ cellView: some View,
                                 conversationBinding: Binding<Conversation>,
                                 navigationTitle: String) -> some View {
        guard ThemeService.currentTheme == AppThemes.default else { return AnyView(cellView) }
        return AnyView(cellView.contextMenu(menuItems: {
            Button(role: .destructive) {
                Core.gcd.after(milliseconds: 200) {
                    RuntimeStorage.conversationsPageViewModel?.deleteConversation(conversation)
                }
            } label: {
                Label(LocalizedString.delete, systemImage: "trash")
            }
        }, preview: {
            chatPageView(conversation: conversationBinding, title: navigationTitle)
                .onAppear {
                    RuntimeStorage.store(conversation, as: .globalConversation)
                    RuntimeStorage.store(conversation.get(.last,
                                                          messages: 10,
                                                          offset: RuntimeStorage.messageOffset),
                                         as: .currentMessageSlice)
                    RuntimeStorage.store(true, as: .isPreviewingChat)
                }
                .onDisappear {
                    RuntimeStorage.store(false, as: .isPreviewingChat)
                }
        }))
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func getCellSubtitle(forMessage: Message) -> String {
        guard forMessage.audioComponent == nil else { return "🔊 \(LocalizedString.audioMessage)" }
        
        guard forMessage.fromAccountIdentifier == RuntimeStorage.currentUserID! else { return forMessage.translation.output }
        return forMessage.translation.input.value()
    }
    
    private func getLanguageAndRegionString(languageCode: String,
                                            regionCode: String) -> String {
        let localizedRegionName = RegionDetailServer.getLocalizedRegionString(forRegionCode: regionCode)
        
        let code = languageCode == "ua" ? "uk" : languageCode
        var languageName = "\(code.uppercased())"
        if let localizedName = code.localizedLanguageName {
            languageName = "\(localizedName) *(\(code.uppercased()))*"
        }
        
        return "Language*: \(languageName)\n*Region*: \(localizedRegionName)*"
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
    
    /* MARK: - Methods */
    
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
    
    /* MARK: - Methods */
    
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
