//
//  Core+Extensions.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 06/05/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/* Third-party Frameworks */
import Translator

public extension Core {
    static func clearCaches() {
        ContactArchiver.clearArchive()
        ContactService.clearCache()
        ConversationArchiver.clearArchive()
        RecognitionService.clearCache()
        RegionDetailServer.clearCache()
        TranslationArchiver.clearArchive()
    }
    
    static func open(_ url: URL) {
#if !EXTENSION
        UIApplication.shared.open(url)
#endif
    }
}
