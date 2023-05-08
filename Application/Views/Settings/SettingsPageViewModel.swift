//
//  SettingsPageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 13/04/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import AlertKit
import Translator
import Contacts

public class SettingsPageViewModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Enums */
    
    public enum State {
        case idle
        case loading
        case failed(Exception)
        case loaded(translations: [String: Translator.Translation],
                    contact: CNContact?)
    }
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Strings
    public var userSubtitle = ""
    public var userTitle = ""
    
    // Other
    public var userThumbnail: UIImage?
    
    private let inputs = ["change_theme": Translator.TranslationInput("Change Theme", alternate: "Change Appearance"),
                          "clear_caches": Translator.TranslationInput("Clear Caches"),
                          "log_out": Translator.TranslationInput("Log Out"),
                          "version": Translator.TranslationInput("Version")]
    
    @Published private(set) var state = State.idle
    
    //==================================================//
    
    /* MARK: - Initializer Method */
    
    public func load() {
        state = .loading
        
        guard let currentUser = RuntimeStorage.currentUser else {
            state = .failed(Exception("No current user!", metadata: [#file, #function, #line]))
            return
        }
        
        userTitle = currentUser.cellTitle
        let formattedPhoneNumber = currentUser.compiledPhoneNumber.phoneNumberFormatted
        userSubtitle = userTitle == formattedPhoneNumber ? "" : formattedPhoneNumber
        userThumbnail = ContactService.fetchContactThumbnail(forUser: currentUser)
        
        let dataModel = PageViewDataModel(inputs: inputs)
        dataModel.translateStrings { translations, exception in
            guard let translations else {
                self.state = .failed(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            ContactService.fetchContact(forUser: currentUser) { match, exception in
                self.state = .loaded(translations: translations, contact: match)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Public Methods */
    
    public func changeTheme() {
        var actions = [AKAction]()
        var actionIDs = [Int: String]()
        
        for theme in AppThemes.list {
            guard theme.name != ThemeService.currentTheme.name else { continue }
            let action = AKAction(title: theme.name, style: .default)
            actions.append(action)
            actionIDs[action.identifier] = theme.name
        }
        
        AKActionSheet(message: "Change Theme",
                      actions: actions,
                      shouldTranslate: [.message]).present { actionID in
            guard actionID != -1,
                  let themeName = actionIDs[actionID],
                  let correspondingTheme = AppThemes.list.first(where: { $0.name == themeName }) else { return }
            
            ThemeService.setTheme(correspondingTheme)
        }
    }
    
    public func confirmClearCaches() {
        let alert = AKConfirmationAlert(title: "Clear Caches",
                                        message: "Are you sure you'd like to clear all caches?\n\nThis may fix some issues, but can also temporarily slow down the app while indexes rebuild.\n\nYou will need to restart the app for this to take effect.",
                                        confirmationStyle: .destructivePreferred)
        alert.present { confirmed in
            guard confirmed == 1 else { return }
            self.clearCaches()
        }
    }
    
    public func confirmSignOut(_ viewRouter: ViewRouter) {
        AKActionSheet(message: "Log Out",
                      actions: [AKAction(title: "Log Out", style: .destructivePreferred)]).present { actionID in
            guard actionID != -1 else { return }
            self.signOut(viewRouter)
        }
    }
    
    public func developerModeItems() -> [StaticListItem] {
        guard Build.stage != .generalRelease,
              let currentUser = RuntimeStorage.currentUser else { return [] }
        
        var items = [StaticListItem]()
        
        if Build.developerModeEnabled,
           currentUser.languageCode != "en" {
            let languageCode = currentUser.languageCode!
            let languageName = languageCode.languageName ?? languageCode.uppercased()
            
            let overrideOrRestore = AKCore.shared.languageCodeIsLocked ? "Restore Language to \(languageName)" : "Override Language Code to English"
            items.append(StaticListItem(title: overrideOrRestore,
                                        imageData: (Image(systemName: "square.text.square.fill"), .mint),
                                        action: overrideLanguageCode))
        }
        
        if !Build.developerModeEnabled,
           let window = RuntimeStorage.topWindow!.subview(Core.ui.nameTag(for: "buildInfoOverlayWindow")) as? UIWindow,
           window.isHidden {
            items.append(StaticListItem(title: "Toggle Developer Mode",
                                        imageData: (Image(systemName: "command.square.fill"), .yellow),
                                        action: toggleDeveloperMode))
        }
        
        return items
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func clearCaches() {
        ContactArchiver.clearArchive()
        ContactService.clearCache()
        ConversationArchiver.clearArchive()
        RecognitionService.clearCache()
        RegionDetailServer.clearCache()
        TranslationArchiver.clearArchive()
        
        AnalyticsService.logEvent(.clearCaches)
        
        UserDefaults.standard.set(nil, forKey: "archivedLocalUserHashes")
        UserDefaults.standard.set(nil, forKey: "archivedServerUserHashes")
        
        AKAlert(message: "Caches have been cleared. You must now restart the app.",
                actions: [AKAction(title: "Exit", style: .destructivePreferred)],
                showsCancelButton: false).present { _ in
            fatalError()
        }
    }
    
    private func overrideLanguageCode() {
        StateProvider.shared.shouldDismissSettingsPage = true
        Core.gcd.after(milliseconds: 500) {
            guard !AKCore.shared.languageCodeIsLocked else {
                RuntimeStorage.remove(.overriddenLanguageCode)
                AKCore.shared.unlockLanguageCode(andSetTo: RuntimeStorage.languageCode)
                
                guard let currentUser = RuntimeStorage.currentUser else { return }
                let languageCode = currentUser.languageCode!
                let languageName = languageCode.languageName ?? languageCode.uppercased()
                Core.hud.showSuccess(text: "Set to \(languageName)")
                
                return
            }
            
            RuntimeStorage.store("en", as: .overriddenLanguageCode)
            AKCore.shared.lockLanguageCode(to: "en")
            
            Core.hud.showSuccess(text: "Set to English")
        }
    }
    
    private func signOut(_ viewRouter: ViewRouter) {
        AnalyticsService.logEvent(.logOut)
        
        ConversationArchiver.clearArchive()
        ContactArchiver.clearArchive()
        
        RuntimeStorage.store(false, as: .shouldReloadData)
        RuntimeStorage.store(0, as: .messageOffset)
        
        UserDefaults.standard.setValue(nil, forKey: "currentUserID")
        
        RuntimeStorage.remove(.currentUser)
        RuntimeStorage.remove(.currentUserID)
        
        Core.restoreDeviceLanguageCode()
        
        viewRouter.currentPage = .initial
    }
    
    private func toggleDeveloperMode() {
        StateProvider.shared.shouldDismissSettingsPage = true
        Core.gcd.after(seconds: 1) { DevModeService.promptToToggle() }
    }
}
