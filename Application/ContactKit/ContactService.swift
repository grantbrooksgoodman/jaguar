//
//  ContactService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 06/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import ContactsUI

public enum ContactService {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Dictionaries
    private static var names = [String: (String, String)]()
    private static var thumbnails = [String: UIImage]()
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public static func clearCache() {
        thumbnails = [:]
        names = [:]
    }
    
    public static func fetchAllContacts() -> [Contact] {
        var contacts = [Contact]()
        
        let contactStore = CNContactStore()
        let queryKeys = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                         CNContactPhoneNumbersKey] as [Any]
        let fetchRequest = CNContactFetchRequest(keysToFetch: queryKeys as! [CNKeyDescriptor])
        
        do {
            try contactStore.enumerateContacts(with: fetchRequest, usingBlock: { contact,
                _ in
                if !contact.phoneNumbers.isEmpty {
                    contacts.append(Contact(firstName: contact.givenName,
                                            lastName: contact.familyName,
                                            phoneNumbers: contact.phoneNumbers.asPhoneNumbers()))
                }
            })
        } catch {
            Logger.log("Unable to fetch contacts.\n\(Logger.errorInfo(error))",
                       metadata: [#file, #function, #line])
        }
        
        contacts = contacts.sorted {
            $0.firstName < $1.firstName
        }
        
        return contacts
    }
    
    public static func fetchContactName(forNumber: String) -> (givenName: String, familyName: String)? {
        guard names[forNumber] == nil else {
            return names[forNumber]!
        }
        
        let queryDigits = forNumber.digits
        
        var contactName: (String, String)?
        
        let contactStore = CNContactStore()
        let queryKeys = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                         CNContactPhoneNumbersKey] as [Any]
        let fetchRequest = CNContactFetchRequest(keysToFetch: queryKeys as! [CNKeyDescriptor])
        
        do {
            try contactStore.enumerateContacts(with: fetchRequest, usingBlock: { contact,
                _ in
                for phoneNumber in contact.phoneNumbers {
                    if phoneNumber.value.stringValue.digits == queryDigits ||
                        phoneNumber.value.stringValue.digits.dropPrefix(1) == queryDigits ||
                        phoneNumber.value.stringValue.digits.dropPrefix(2) == queryDigits ||
                        phoneNumber.value.stringValue.digits.dropPrefix(3) == queryDigits {
                        contactName = (contact.givenName, contact.familyName)
                    }
                }
            })
        } catch {
            Logger.log("Unable to fetch contact name.\n\(Logger.errorInfo(error))",
                       metadata: [#file, #function, #line])
            return nil
        }
        
        names[forNumber] = contactName ?? ("", "")
        
        return contactName
    }
    
    public static func fetchContactThumbnail(forNumber: String) -> UIImage? {
        guard thumbnails[forNumber] == nil else {
            return thumbnails[forNumber]!
        }
        
        let queryDigits = forNumber.digits
        
        var thumbnailImage: UIImage?
        
        let contactStore = CNContactStore()
        let queryKeys = [CNContactImageDataAvailableKey,
                         CNContactImageDataKey,
                         CNContactPhoneNumbersKey] as [Any]
        let fetchRequest = CNContactFetchRequest(keysToFetch: queryKeys as! [CNKeyDescriptor])
        
        do {
            try contactStore.enumerateContacts(with: fetchRequest, usingBlock: { contact,
                _ in
                for phoneNumber in contact.phoneNumbers {
                    if phoneNumber.value.stringValue.digits == queryDigits ||
                        phoneNumber.value.stringValue.digits.dropPrefix(1) == queryDigits ||
                        phoneNumber.value.stringValue.digits.dropPrefix(2) == queryDigits ||
                        phoneNumber.value.stringValue.digits.dropPrefix(3) == queryDigits,
                       contact.imageDataAvailable,
                       let imageData = contact.imageData
                    {
                        thumbnailImage = UIImage(data: imageData)
                    }
                }
            })
        } catch {
            Logger.log("Unable to fetch contact image data.\n\(Logger.errorInfo(error))",
                       metadata: [#file, #function, #line])
            return nil
        }
        
        thumbnails[forNumber] = thumbnailImage ?? UIImage()
        
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
