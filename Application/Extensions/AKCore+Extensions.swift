//
//  AKCore+Extensions.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 26/02/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/* Third-party Frameworks */
import AlertKit

public extension AKCore {
    static func presentOfflineAlert() {
        let exception = Exception("The internet connection is offline.",
                                  isReportable: false,
                                  extraParams: ["IsConnected": Build.isOnline],
                                  metadata: [#file, #function, #line])
        
        var settingsURL: URL?
        var actions = [AKAction]()
        
#if !EXTENSION
        if let urlString = RuntimeStorage.redirectionKey,
           let asURL = URL(string: massageRedirectionKey(urlString)),
           UIApplication.shared.canOpenURL(asURL) {
            settingsURL = asURL
            actions.append(AKAction(title: LocalizedString.settings, style: .default))
        }
#endif
        
        guard let languageCode = RuntimeStorage.languageCode else { return }
        
        let errorAlert = AKErrorAlert(message: Localizer.preLocalizedString(for: .noInternetMessage,
                                                                            language: languageCode) ?? "The internet connection appears to be offline.\nPlease connect to the internet and try again.",
                                      error: exception.asAkError(),
                                      actions: actions.isEmpty ? nil : actions,
                                      cancelButtonTitle: "OK",
                                      shouldTranslate: [.none])
        
        errorAlert.present { actionID in
            guard actionID == errorAlert.actions.first(where: { $0.title == LocalizedString.settings })?.identifier,
                  let settingsURL else { return }
#if !EXTENSION
            UIApplication.shared.open(settingsURL)
#endif
        }
    }
    
    private static func massageRedirectionKey(_ string: String) -> String {
        var lowercasedString = string.lowercased().ciphered(by: 12)
        lowercasedString = lowercasedString.replacingOccurrences(of: "g", with: "-")
        lowercasedString = lowercasedString.replacingOccurrences(of: "n", with: ":")
        
        var capitalizedCharacters = [String]()
        for (index, character) in lowercasedString.characterArray.enumerated() {
            let finalCharacter = (index == 0 || index == 4) ? character.uppercased() : character
            capitalizedCharacters.append(finalCharacter)
        }
        
        return capitalizedCharacters.joined()
    }
}
