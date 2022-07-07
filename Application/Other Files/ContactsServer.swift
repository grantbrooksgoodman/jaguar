//
//  ContactsServer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 06/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import ContactsUI
import Foundation

public class ContactsServer {
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public static func fetchContactName(forNumber: String) -> String? {
        let queryDigits = forNumber.digits
        
        var contactName = ""
        
        let contactStore = CNContactStore()
        let queryKeys = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                         CNContactPhoneNumbersKey] as [Any]
        let fetchRequest = CNContactFetchRequest(keysToFetch: queryKeys as! [CNKeyDescriptor])
        
        do {
            try contactStore.enumerateContacts(with: fetchRequest, usingBlock: { (contact,
                                                                                  end) in
                for phoneNumber in contact.phoneNumbers {
                    if phoneNumber.value.stringValue.digits == queryDigits {
                        contactName = "\(contact.givenName) \(contact.familyName)"
                    }
                }
            })
        } catch {
            log("Unable to fetch contact name.",
                metadata: [#file, #function, #line])
            return nil
        }
        
        return contactName == "" ? nil : contactName
    }
    
    public static func fetchContactThumbnail(forNumber: String) -> UIImage? {
        let queryDigits = forNumber.digits
        
        var thumbnailImage: UIImage?
        
        let contactStore = CNContactStore()
        let queryKeys = [CNContactImageDataAvailableKey,
                         CNContactImageDataKey,
                         CNContactPhoneNumbersKey] as [Any]
        let fetchRequest = CNContactFetchRequest(keysToFetch: queryKeys as! [CNKeyDescriptor])
        
        do {
            try contactStore.enumerateContacts(with: fetchRequest, usingBlock: { (contact,
                                                                                  end) in
                for phoneNumber in contact.phoneNumbers {
                    if phoneNumber.value.stringValue.digits == queryDigits,
                       contact.imageDataAvailable,
                       let imageData = contact.imageData {
                        thumbnailImage = UIImage(data: imageData)
                    }
                }
            })
        } catch {
            log("Unable to fetch contact image data.",
                metadata: [#file, #function, #line])
            return nil
        }
        
        return thumbnailImage
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: String */
public extension String {
    var digits: String {
        return components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
}
