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
        
        let settingsUrl = URL(string: UIApplication.openSettingsURLString)
        
        var actions = [AKAction]()
#if !EXTENSION
        if let settingsUrl,
           UIApplication.shared.canOpenURL(settingsUrl) {
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
                  let settingsUrl else { return }
            
#if !EXTENSION
            UIApplication.shared.open(settingsUrl)
#endif
        }
    }
}
