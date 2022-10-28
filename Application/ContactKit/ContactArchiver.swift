//
//  ContactArchiver.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 28/09/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public enum ContactArchiver {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private(set) static var contactArchive = [ContactPair]() { didSet { ContactArchiver.setArchive() } }
    
    //==================================================//
    
    /* MARK: - Addition/Retrieval Functions */
    
    public static func addToArchive(_ contactPair: ContactPair) {
        initializeArchive()
        
        contactArchive.removeAll(where: { $0.contact.hash == contactPair.contact.hash })
        contactArchive.append(contactPair)
        
        Logger.log("Added contact to local archive.",
                   verbose: true,
                   metadata: [#file, #function, #line])
    }
    
    public static func addToArchive(_ contactPairs: [ContactPair]) {
        initializeArchive()
        
        contactArchive.removeAll(where: { $0.contact.hash.isAny(in: contactPairs.contacts.hashes()) })
        contactArchive.append(contentsOf: contactPairs)
        
        Logger.log("Added contacts to local archive.",
                   verbose: true,
                   metadata: [#file, #function, #line])
    }
    
    public static func getFromArchive(_ hash: String) -> ContactPair? {
        initializeArchive()
        
        let contacts = contactArchive.filter { $0.contact.hash == hash }
        
        return contacts.first
    }
    
    public static func getFromArchive(withPhoneNumbers: [String]) -> ContactPair? {
        initializeArchive()
        
        let contacts = contactArchive.filter({ $0.contact.phoneNumbers.digits.containsAny(in: withPhoneNumbers) })
        
        return contacts.first
    }
    
    //==================================================//
    
    /* MARK: - Getter/Setter Functions */
    
    public static func clearArchive() {
        contactArchive = []
        UserDefaults.standard.setValue(nil, forKey: "contactArchive")
    }
    
    public static func getArchive(completion: @escaping (_ returnedContactPairs: [ContactPair]?,
                                                         _ exception: Exception?) -> Void) {
        guard let contactData = UserDefaults.standard.object(forKey: "contactArchive") as? Data else {
            completion(nil, Exception("Couldn't decode contact archive. May be empty.",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let decodedContacts = try decoder.decode([ContactPair].self,
                                                     from: contactData)
            
            contactArchive = decodedContacts
            completion(decodedContacts, nil)
            return
        } catch {
            Logger.log(Exception(error,
                                 metadata: [#file, #function, #line]))
            
            completion(nil, Exception(error, metadata: [#file, #function, #line]))
        }
    }
    
    public static func setArchive(completion: @escaping (_ exception: Exception?) -> Void = { _ in }) {
        do {
            let encoder = JSONEncoder()
            let encodedContacts = try encoder.encode(contactArchive)
            
            UserDefaults.standard.setValue(encodedContacts, forKey: "contactArchive")
            completion(nil)
        } catch {
            Logger.log(Exception(error,
                                 metadata: [#file, #function, #line]))
            
            completion(Exception(error, metadata: [#file, #function, #line]))
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private static func initializeArchive() {
        getArchive { returnedContactPairs,
            _ in
            guard let contacts = returnedContactPairs else {
                return
            }
            
            contactArchive = contacts
        }
    }
}
