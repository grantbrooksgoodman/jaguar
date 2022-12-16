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
    
    /* MARK: - Authorization */
    
    public static func requestAccess(completion: @escaping(_ exception: Exception?) -> Void) {
        let contactStore = CNContactStore()
        
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            completion(nil)
        default:
            contactStore.requestAccess(for: .contacts) { granted, error in
                completion(error == nil ? nil : Exception(error!, metadata: [#file, #function, #line]))
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - CNContactStore Fetching */
    
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
            Logger.log(Exception(error,
                                 extraParams: ["UserFacingDescriptor": "Unable to fetch contacts."],
                                 metadata: [#file, #function, #line]))
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
                    if phoneNumber.value.stringValue.possibleRawNumbers().contains(queryDigits) {
                        contactName = (contact.givenName, contact.familyName)
                    }
                }
            })
        } catch {
            Logger.log(Exception(error,
                                 extraParams: ["UserFacingDescriptor": "Unable to fetch contact name."],
                                 metadata: [#file, #function, #line]))
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
                    if phoneNumber.value.stringValue.possibleRawNumbers().contains(queryDigits),
                       contact.imageDataAvailable,
                       let imageData = contact.imageData {
                        thumbnailImage = UIImage(data: imageData)
                    }
                }
            })
        } catch {
            Logger.log(Exception(error,
                                 extraParams: ["UserFacingDescriptor": "Unable to fetch contact image data."],
                                 metadata: [#file, #function, #line]))
            return nil
        }
        
        thumbnails[forNumber] = thumbnailImage ?? UIImage()
        
        return thumbnailImage
    }
    
    //==================================================//
    
    /* MARK: - Database Comparison */
    
    public static func getLocalUserHashes() -> [String] {
        var hashes = [String]()
        
        for contact in fetchAllContacts() {
            let possibleHashes = PhoneNumberService.possibleHashes(forNumbers: contact.phoneNumbers.digits)
            hashes.append(contentsOf: possibleHashes)
        }
        
        return hashes
    }
    
    public static func getServerUserHashes(completion: @escaping(_ returnedHashes: [String]?,
                                                                 _ exception: Exception?) -> Void) {
        GeneralSerializer.getValues(atPath: "/userHashes") { returnedValues, exception in
            guard let values = returnedValues as? [String: Any] else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(Array(values.keys), nil)
        }
    }
    
    // #warning("Can likely make this more granular by determining which contacts have changed locally.")
    private static func determineSynchronizationStatus(completion: @escaping(_ shouldUpdate: Bool,
                                                                             _ exception: Exception?) -> Void) {
        guard let localArchive = RuntimeStorage.archivedLocalUserHashes,
              localArchive.sorted() == getLocalUserHashes().sorted(),
              let serverArchive = RuntimeStorage.archivedServerUserHashes else {
            completion(true, nil)
            return
        }
        
        getServerUserHashes { returnedHashes, exception in
            guard let updatedServerUserHashes = returnedHashes else {
                completion(true, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            guard serverArchive.sorted() == updatedServerUserHashes.sorted() else {
                completion(true, nil)
                return
            }
            
            var archivedContactCount = 0
            let filtered = updatedServerUserHashes.filter({ RuntimeStorage.archivedLocalUserHashes!.contains($0) })
            filtered.forEach { hash in
                archivedContactCount += ContactArchiver.getFromArchive(withUserHash: hash) != nil ? 1 : 0
            }
            
            let shouldUpdate = archivedContactCount != filtered.count
            if shouldUpdate {
                UserDefaults.standard.set(updatedServerUserHashes, forKey: "archivedServerUserHashes")
                RuntimeStorage.store(updatedServerUserHashes, as: .archivedServerUserHashes)
            }
            
            completion(shouldUpdate, nil)
        }
    }
    
    public static func loadContacts(completion: @escaping(_ contactPairs: [ContactPair]?,
                                                          _ exception: Exception?) -> Void) {
        determineSynchronizationStatus { shouldUpdate, exception in
            guard exception == nil else {
                completion(nil, exception)
                return
            }
            
            if shouldUpdate {
                let updatedLocalUserHashes = getLocalUserHashes()
                UserDefaults.standard.set(updatedLocalUserHashes, forKey: "archivedLocalUserHashes")
                RuntimeStorage.store(updatedLocalUserHashes, as: .archivedLocalUserHashes)
                
                updateContacts { contactPairs, exception in
                    guard let pairs = contactPairs else {
                        completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                        return
                    }
                    
                    completion(pairs, nil)
                }
            } else {
                ContactArchiver.getArchive { contactPairs, exception in
                    guard let pairs = contactPairs else {
                        completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                        return
                    }
                    
                    completion(pairs, nil)
                }
            }
        }
    }
    
    private static func updateContacts(completion: @escaping(_ contactPairs: [ContactPair]?,
                                                             _ exception: Exception?) -> Void) {
        let sorted = fetchAllContacts().sorted
        guard var contactsToReturn = sorted[0] as? [ContactPair],
              let contactsToFetch = sorted[1] as? [Contact] else {
            let exception = Exception("Unable to sort contacts.",
                                      metadata: [#file, #function, #line])
            
            Logger.log(exception)
            completion(nil, exception)
            
            return
        }
        
        guard !contactsToFetch.isEmpty else {
            guard !contactsToReturn.isEmpty else {
                completion(nil, Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(contactsToReturn, nil)
            return
        }
        
        UserSerializer.shared.findUsers(forContacts: contactsToFetch) { returnedContactPairs, exception in
            guard let contactPairs = returnedContactPairs else {
                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]))
                
                let isEmpty = contactsToReturn.uniquePairs.isEmpty
                completion(isEmpty ? nil : contactsToReturn.uniquePairs,
                           isEmpty ? exception ?? Exception(metadata: [#file, #function, #line]) : nil)
                return
            }
            
            ContactArchiver.addToArchive(contactPairs)
            contactsToReturn.append(contentsOf: contactPairs)
            
            completion(contactsToReturn.uniquePairs, nil)
        }
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    public static func clearCache() {
        thumbnails = [:]
        names = [:]
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
