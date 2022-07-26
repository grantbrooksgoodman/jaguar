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
    
    public static func fetchAllContacts() -> [ContactInfo] {
        var contacts = [ContactInfo]()
        
        let contactStore = CNContactStore()
        let queryKeys = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                         CNContactPhoneNumbersKey] as [Any]
        let fetchRequest = CNContactFetchRequest(keysToFetch: queryKeys as! [CNKeyDescriptor])
        
        do {
            try contactStore.enumerateContacts(with: fetchRequest, usingBlock: { (contact,
                                                                                  endPointer) in
                contacts.append(ContactInfo(firstName: contact.givenName,
                                            lastName: contact.familyName,
                                            phoneNumber: contact.phoneNumbers.first?.value))
            })
        } catch let error {
            Logger.log("Unable to fetch contacts.\n\(Logger.errorInfo(error))",
                       metadata: [#file, #function, #line])
        }
        
        contacts = contacts.sorted {
            $0.firstName < $1.firstName
        }
        
        return contacts
    }
    
    public static func fetchContactName(forNumber: String) -> (givenName: String, familyName: String)? {
        let queryDigits = forNumber.digits
        
        var contactName: (String, String)?
        
        let contactStore = CNContactStore()
        let queryKeys = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                         CNContactPhoneNumbersKey] as [Any]
        let fetchRequest = CNContactFetchRequest(keysToFetch: queryKeys as! [CNKeyDescriptor])
        
        do {
            try contactStore.enumerateContacts(with: fetchRequest, usingBlock: { (contact,
                                                                                  endPointer) in
                for phoneNumber in contact.phoneNumbers {
                    if phoneNumber.value.stringValue.digits == queryDigits {
                        contactName = (contact.givenName, contact.familyName)
                    }
                }
            })
        } catch let error {
            Logger.log("Unable to fetch contact name.\n\(Logger.errorInfo(error))",
                       metadata: [#file, #function, #line])
            return nil
        }
        
        return contactName
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
                                                                                  endPointer) in
                for phoneNumber in contact.phoneNumbers {
                    if phoneNumber.value.stringValue.digits == queryDigits,
                       contact.imageDataAvailable,
                       let imageData = contact.imageData {
                        thumbnailImage = UIImage(data: imageData)
                    }
                }
            })
        } catch let error {
            Logger.log("Unable to fetch contact image data.\n\(Logger.errorInfo(error))",
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
