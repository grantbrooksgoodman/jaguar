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
    
    private static var cachedContacts: [Contact]?
    
    //==================================================//
    
    /* MARK: - CNContactStore Fetching */
    
    public static func fetchAllContacts(forceUpdate: Bool,
                                        completion: @escaping(_ contacts: [Contact]?,
                                                              _ exception: Exception?) -> Void) {
        if !forceUpdate,
           let cachedContacts {
            completion(cachedContacts, nil)
            return
        }
        
        var contacts = [Contact]()
        
        let contactStore = CNContactStore()
        let queryKeys = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                         CNContactPhoneNumbersKey,
                         CNContactThumbnailImageDataKey] as [Any]
        let fetchRequest = CNContactFetchRequest(keysToFetch: queryKeys as! [CNKeyDescriptor])
        
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try contactStore.enumerateContacts(with: fetchRequest, usingBlock: { contact,
                    _ in
                    if !contact.phoneNumbers.isEmpty {
                        contacts.append(Contact(firstName: contact.givenName,
                                                lastName: contact.familyName,
                                                phoneNumbers: contact.phoneNumbers.asPhoneNumbers(),
                                                imageData: contact.thumbnailImageData))
                    }
                })
            } catch {
                completion(nil, Exception(error,
                                          extraParams: ["UserFacingDescriptor": "Unable to fetch contacts."],
                                          metadata: [#file, #function, #line]))
            }
            
            contacts = contacts.sorted {
                $0.firstName < $1.firstName
            }
            
            self.cachedContacts = contacts
            completion(contacts.isEmpty ? nil : contacts,
                       contacts.isEmpty ? Exception("Empty contact list.",
                                                    metadata: [#file, #function, #line]) : nil)
        }
    }
    
    // #warning("Clean this up.")
    public static func fetchContact(forUser: User,
                                    completion: @escaping(_ match: CNContact?,
                                                          _ exception: Exception?) -> Void) {
        let contactStore = CNContactStore()
        let queryKeys = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                         CNContactPhoneNumbersKey,
                         CNContactThumbnailImageDataKey,
                         CNContactViewController.descriptorForRequiredKeys()] as [Any]
        let fetchRequest = CNContactFetchRequest(keysToFetch: queryKeys as! [CNKeyDescriptor])
        
        var match: CNContact?
        
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try contactStore.enumerateContacts(with: fetchRequest, usingBlock: { contact,
                    _ in
                    let phoneNumbers = contact.phoneNumbers.asPhoneNumbers().digits
                    for number in phoneNumbers {
                        guard let hashes = PhoneNumberService.possibleHashes(for: number),
                              let callingCodes = PhoneNumberService.possibleCallingCodes(for: number),
                              hashes.contains(forUser.phoneNumber.digits.compressedHash),
                              callingCodes.contains(forUser.callingCode) else { continue }
                        
                        match = contact
                    }
                })
            } catch {
                completion(nil, Exception(error,
                                          extraParams: ["UserFacingDescriptor": "Unable to fetch contacts."],
                                          metadata: [#file, #function, #line]))
            }
            
            completion(match, match == nil ? Exception(metadata: [#file, #function, #line]) : nil)
        }
    }
    
    public static func fetchContactName(forUser: User) -> (givenName: String, familyName: String)? {
        guard let archivedPair = ContactArchiver.getFromArchive(withUserHash: forUser.phoneNumber.compressedHash) else { return nil }
        
        let firstName = archivedPair.contact.firstName
        let lastName = archivedPair.contact.lastName
        
        return (givenName: firstName, familyName: lastName)
    }
    
    public static func fetchContactThumbnail(forUser: User) -> UIImage? {
        guard let archivedPair = ContactArchiver.getFromArchive(withUserHash: forUser.phoneNumber.compressedHash),
              let imageData = archivedPair.contact.imageData else { return nil }
        
        return UIImage(data: imageData)
    }
    
    //==================================================//
    
    /* MARK: - Hash Retrieval */
    
    public static func getLocalUserHashes(completion: @escaping(_ hashes: [String]?,
                                                                _ exception: Exception?) -> Void) {
        var hashes = [String]()
        fetchAllContacts(forceUpdate: true) { contacts, exception in
            guard let contacts else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            contacts.forEach { contact in
                for number in contact.phoneNumbers {
                    guard let possibleHashes = PhoneNumberService.possibleHashes(for: number.digits),
                          !possibleHashes.isEmpty else { continue }
                    
                    hashes.append(contentsOf: possibleHashes)
                }
            }
            
            completion(hashes, nil)
        }
    }
    
    public static func getServerUserHashes(completion: @escaping(_ hashes: [String]?,
                                                                 _ exception: Exception?) -> Void) {
        GeneralSerializer.getValues(atPath: "/\(GeneralSerializer.environment.shortString)/userHashes") { returnedValues, exception in
            guard let values = returnedValues as? [String: Any] else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(Array(values.keys), nil)
        }
    }
    
    //==================================================//
    
    /* MARK: - Database Comparison */
    
    // #warning("Can likely make this more granular by determining which contacts have changed locally.")
    private static func determineSynchronizationStatus(completion: @escaping(_ shouldUpdate: Bool,
                                                                             _ exception: Exception?) -> Void) {
        getLocalUserHashes { localHashes, exception in
            guard let localHashes else {
                completion(true, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            guard let localArchive = RuntimeStorage.archivedLocalUserHashes,
                  localArchive.sorted() == localHashes.sorted(),
                  let serverArchive = RuntimeStorage.archivedServerUserHashes else {
                completion(true, nil)
                return
            }
            
            getServerUserHashes { serverHashes, exception in
                guard let updatedServerUserHashes = serverHashes else {
                    completion(true, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                guard serverArchive.sorted() == updatedServerUserHashes.sorted() else {
                    // #warning("I *think* this should be here, but having trouble with the logic.")
                    UserDefaults.standard.set(updatedServerUserHashes, forKey: UserDefaultsKeys.archivedServerUserHashesKey)
                    RuntimeStorage.store(updatedServerUserHashes, as: .archivedServerUserHashes)
                    
                    completion(true, nil)
                    return
                }
                
                var archivedContactCount = 0
                var filtered = updatedServerUserHashes.filter({ RuntimeStorage.archivedLocalUserHashes!.contains($0) })
                filtered = filtered.filter({ !RuntimeStorage.mismatchedHashes!.contains($0) })
                
                filtered.forEach { hash in
                    archivedContactCount += ContactArchiver.getFromArchive(withUserHash: hash) != nil ? 1 : 0
                }
                
                print("missing: \(filtered.filter({ ContactArchiver.getFromArchive(withUserHash: $0) == nil }).first ?? "none")")
                
                guard !filtered.isEmpty else {
                    completion(true, nil)
                    return
                }
                
                let shouldUpdate = archivedContactCount != filtered.count
                if shouldUpdate {
                    UserDefaults.standard.set(updatedServerUserHashes, forKey: UserDefaultsKeys.archivedServerUserHashesKey)
                    RuntimeStorage.store(updatedServerUserHashes, as: .archivedServerUserHashes)
                }
                
                completion(shouldUpdate, nil)
            }
        }
    }
    
    public static func loadContacts(completion: @escaping(_ contactPairs: [ContactPair]?,
                                                          _ exception: Exception?) -> Void) {
        guard PermissionService.contactPermissionStatus == .granted else {
            completion(nil, Exception("Not authorized to access contacts.", metadata: [#file, #function, #line]))
            return
        }
        
        fetchAllContacts(forceUpdate: false) { contacts, exception in
            guard let contacts,
                  !contacts.isEmpty else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            determineSynchronizationStatus { shouldUpdate, exception in
                guard exception == nil else {
                    completion(nil, exception)
                    return
                }
                
                if shouldUpdate {
                    Logger.log("Contacts need updating.", metadata: [#file, #function, #line])
                    
                    getLocalUserHashes { updatedLocalUserHashes, exception in
                        guard let updatedLocalUserHashes else {
                            completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                            return
                        }
                        
                        UserDefaults.standard.set(updatedLocalUserHashes, forKey: UserDefaultsKeys.archivedLocalUserHashesKey)
                        RuntimeStorage.store(updatedLocalUserHashes, as: .archivedLocalUserHashes)
                        
                        updateContacts { contactPairs, exception in
                            guard let pairs = contactPairs else {
                                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                                return
                            }
                            
                            completion(pairs, nil)
                        }
                    }
                } else {
                    Logger.log("Contacts match archive!", metadata: [#file, #function, #line])
                    
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
    }
    
    private static func updateContacts(completion: @escaping(_ contactPairs: [ContactPair]?,
                                                             _ exception: Exception?) -> Void) {
        fetchAllContacts(forceUpdate: false) { contacts, exception in
            guard let contacts else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            let sorted = contacts.sorted
            guard var contactsToReturn = sorted[0] as? [ContactPair],
                  let contactsToFetch = sorted[1] as? [Contact] else {
                let exception = Exception("Unable to sort contacts.", metadata: [#file, #function, #line])
                
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
            
            UserSerializer.shared.findUsers(for: contactsToFetch) { pairs, exception in
                guard let pairs else {
                    let isEmpty = contactsToReturn.isEmpty
                    completion(isEmpty ? nil : contactsToReturn,
                               isEmpty ? exception ?? Exception("No users found for contacts.",
                                                                metadata: [#file, #function, #line]) : nil)
                    
                    return
                }
                
                ContactArchiver.addToArchive(pairs)
                contactsToReturn.append(contentsOf: pairs)
                
                completion(contactsToReturn, nil)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Other Methods */
    
    public static func clearCache() {
        cachedContacts = nil
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
