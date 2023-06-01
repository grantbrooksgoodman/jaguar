//
//  SettingsPageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 12/04/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import ContactsUI
import Foundation
import SwiftUI

/* Third-party Frameworks */
import AlertKit
import Translator

public struct SettingsPageView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @Binding public var isPresenting: Bool
    @StateObject public var viewModel: SettingsPageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    @State private var buildInfoStringKey: BuildInfoStringKey = .bundleVersionAndBuildNumber
    @ObservedObject private var stateProvider = StateProvider.shared
    
    private enum BuildInfoStringKey {
        case bundleVersionAndBuildNumber
        case buildSKU
        case projectID
        case copyright
    }
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear { viewModel.load() }
        case .loading:
            ProgressView("")
        case .loaded(let translations, let contact):
            ThemedView(reloadsForUpdates: true) {
                bodyView(translations: translations, contact: contact)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.listViewBackgroundColor)
                    .onChange(of: stateProvider.shouldDismissSettingsPage) { newValue in
                        guard newValue else { return }
                        isPresenting = false
                        stateProvider.shouldDismissSettingsPage = false
                    }
            }
        case .failed(let exception):
            FailureView(exception: exception)
        }
    }
    
    public func bodyView(translations: [String: Translator.Translation],
                         contact: CNContact?) -> some View {
        NavigationView {
            ScrollViewReader { _ in
                VStack {
                    if let contact {
                        let contact = Binding(get: { contact },
                                              set: { let _ = $0 })
                        NavigationLink(destination: ContactView(contact: contact)) {
                            contactView
                        }
                    } else {
                        contactView
                    }
                    
                    StaticList(items: [StaticListItem(title: translations["invite_friends"]!.output,
                                                      imageData: (Image(systemName: "location.square.fill"), .blue),
                                                      action: askToTranslate),
                                       StaticListItem(title: translations["leave_a_review"]!.output,
                                                      imageData: (Image(systemName: "star.square.fill"), .yellow),
                                                      action: viewModel.reviewOnAppStore)])
                    .padding(.bottom, 20)
                    
                    StaticList(items: [StaticListItem(title: translations["change_theme"]!.output,
                                                      imageData: (Image(systemName: "eye.square.fill"), .purple),
                                                      action: viewModel.changeTheme),
                                       StaticListItem(title: LocalizedString.sendFeedback,
                                                      imageData: (Image(systemName: "info.square.fill"), .green),
                                                      action: BuildInfoOverlayViewModel().presentSendFeedbackActionSheet)])
                    .padding(.bottom, 20)
                    
                    StaticList(items: [StaticListItem(title: translations["clear_caches"]!.output,
                                                      imageData: (Image(systemName: "trash.square.fill"), .orange),
                                                      action: viewModel.confirmClearCaches),
                                       StaticListItem(title: translations["log_out"]!.output,
                                                      imageData: (Image(systemName: "hand.raised.square.fill"), .red),
                                                      action: confirmSignOut)])
                    .padding(.bottom, 20)
                    
                    if !viewModel.developerModeItems().isEmpty {
                        StaticList(items: viewModel.developerModeItems())
                    }
                    
                    Spacer()
                    
                    buildInfoButton(versionTranslation: translations["version"]!.output)
                }
                .toolbar {
                    doneButton
                }
                .navigationBarTitle(LocalizedString.settings.removingOccurrences(of: ["..."]), displayMode: .inline)
                .interactiveDismissDisabled(true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.listViewBackgroundColor)
        }
        .toolbarBackground(Color.navigationBarBackgroundColor, for: .navigationBar)
    }
    
    //==================================================//
    
    /* MARK: - Toolbar Buttons */
    
    @ToolbarContentBuilder
    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(LocalizedString.done) {
                isPresenting = false
            }
            .foregroundColor(.primaryAccentColor)
        }
    }
    
    //==================================================//
    
    /* MARK: - View Builders */
    
    private func buildInfoButton(versionTranslation: String) -> some View {
        var nextStringKey: BuildInfoStringKey
        var stringToDisplay = ""
        
        switch buildInfoStringKey {
        case .bundleVersionAndBuildNumber:
            nextStringKey = .buildSKU
            stringToDisplay = "\(versionTranslation) \(Build.bundleVersion) (\(String(Build.buildNumber))\(Build.stage.description(short: true)))"
        case .buildSKU:
            nextStringKey = .projectID
            stringToDisplay = Build.buildSKU
        case .projectID:
            nextStringKey = .copyright
            stringToDisplay = Build.projectID
        case .copyright:
            nextStringKey = .bundleVersionAndBuildNumber
            stringToDisplay = "Copyright © \(Core.currentCalendar.component(.year, from: Date())) NEOTechnica Corp."
        }
        
        return Button { } label: {
            if buildInfoStringKey == .copyright {
                let imageStyle = (ColorProvider.shared.interfaceStyle == .dark || ThemeService.currentTheme.style == .dark) ? "White" : "Black"
                Image(uiImage: UIImage(named: "NT (\(imageStyle)).png") ?? UIImage())
                    .resizable()
                    .frame(width: (1000 / 20), height: (515 / 20), alignment: .center)
                    .padding(.bottom, 2)
            }
            
            Text(stringToDisplay)
                .font(Font.custom("SFUIText-Regular", size: 13))
                .foregroundColor(.subtitleTextColor)
                .padding(.bottom, 8)
        }.buttonStyle(StaticButtonStyle()).simultaneousGesture(LongPressGesture()
            .onEnded { _ in
                UIPasteboard.general.string = stringToDisplay
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            })
        .highPriorityGesture(TapGesture()
            .onEnded { _ in
                buildInfoStringKey = nextStringKey
            }
        )
    }
    
    private var contactView: some View {
        HStack(alignment: .center) {
            AvatarImageView(uiImage: viewModel.userThumbnail,
                            dimensions: CGSize(width: 50, height: 50),
                            includePadding: false)
            .padding(.trailing, 2)
            
            VStack(alignment: .leading) {
                Text(viewModel.userTitle)
                    .font(Font.custom("SFUIText-Semibold", size: 17))
                    .foregroundColor(.titleTextColor)
                    .padding(.bottom, 0)
                
                Text(viewModel.userSubtitle)
                    .font(Font.custom("SFUIText-Regular", size: 13))
                    .foregroundColor(.titleTextColor)
            }
            
            Spacer()
            
            if viewModel.userSubtitle.lowercasedTrimmingWhitespace != "" {
                Image(systemName: "chevron.forward")
                    .foregroundColor(.subtitleTextColor)
            }
        }
        .padding()
        .background((ThemeService.currentTheme.style == .dark || ColorProvider.shared.interfaceStyle == .dark) ? Color(uiColor: UIColor(hex: 0x2A2A2C)) : .white)
        .cornerRadius(8)
        .padding(.top, 30)
        .padding(.bottom, 20)
        .padding(.horizontal, 20)
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func askToTranslate() {
        InviteService.askToTranslate { shouldTranslate in
            guard let shouldTranslate else { return }
            isPresenting = false
            
            Core.gcd.after(milliseconds: 1500) {
                if shouldTranslate {
                    stateProvider.showingInviteLanguagePicker = true
                } else {
                    InviteService.composeInvitation()
                }
                
                RuntimeStorage.store(false, as: .wantsToInvite)
            }
        }
    }
    
    private func confirmSignOut() {
        viewModel.confirmSignOut(viewRouter)
    }
}

private struct ContactView: UIViewControllerRepresentable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @Binding var contact: CNContact
    
    //==================================================//
    
    /* MARK: - UIViewControllerRepresentable Methods */
    
    func makeCoordinator() -> ContactView.Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ContactView>) -> CNContactViewController {
        return CNContactViewController(for: contact)
    }
    
    func updateUIViewController(_ uiViewController: CNContactViewController,
                                context: UIViewControllerRepresentableContext<ContactView>) { }
    
    //==================================================//
    
    /* MARK: - Coordinator */
    
    class Coordinator: NSObject, CNContactViewControllerDelegate {
        
        //==================================================//
        
        /* MARK: - Properties */
        
        var parent: ContactView
        
        //==================================================//
        
        /* MARK: - Constructor */
        
        init(_ contactDetail: ContactView) {
            self.parent = contactDetail
        }
    }
}

private struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
