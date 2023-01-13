//
//  NotificationService.swift
//  NotificationService
//
//  Created by Grant Goodman on 12/26/22.
//

import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Modify the notification content here...
            
            let defaults = UserDefaults(suiteName: "group.us.neotechnica.notificationextension")
            var contactArchive = [ContactPair]()
            
            if let defaults {
                guard let contactData = defaults.object(forKey: "contactArchive") as? Data else {
                    print("No contact archive.")
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let decodedContacts = try decoder.decode([ContactPair].self,
                                                             from: contactData)
                    
                    contactArchive = decodedContacts
                } catch {
                    print(error.localizedDescription)
                }
            }
            
            if let userHash = bestAttemptContent.userInfo["userHash"] as? String,
               let match = contactArchive.filter({ PhoneNumberService.possibleHashes(for: $0.contact.phoneNumbers.digits).contains(userHash) }).first {
                bestAttemptContent.title = "\(match.contact.firstName) \(match.contact.lastName)"
                
            } else {
                bestAttemptContent.title = "\(bestAttemptContent.title)"
            }
            
            defaults?.set(bestAttemptContent.userInfo, forKey: "NOTIF_DATA")
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
}
