//
//  NotificationService.swift
//  NotificationService
//
//  Created by Grant Brooks Goodman on 26/12/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    //==================================================//
    
    /* MARK: - Overridden Methods */
    
    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        guard let bestAttemptContent,
              let defaults = UserDefaults(suiteName: "group.us.neotechnica.notificationextension"),
              let contactData = defaults.object(forKey: "contactArchive") as? Data else { return }
        
        var contactArchive = [ContactPair]()
        do {
            let decoder = JSONDecoder()
            let decodedContacts = try decoder.decode([ContactPair].self,
                                                     from: contactData)
            
            contactArchive = decodedContacts
        } catch { print(error.localizedDescription) }
        
        if let userHash = bestAttemptContent.userInfo["userHash"] as? String,
           let match = contactArchive.filter({ PhoneNumberService.possibleHashes(for: $0.contact.phoneNumbers.digits).contains(userHash) }).first {
            bestAttemptContent.title = "\(match.contact.firstName) \(match.contact.lastName)"
        } else {
            bestAttemptContent.title = "\(bestAttemptContent.title)"
        }
        
        defaults.set(bestAttemptContent.userInfo, forKey: "NOTIF_DATA")
        contentHandler(bestAttemptContent)
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
