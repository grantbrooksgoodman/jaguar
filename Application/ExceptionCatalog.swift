//
//  ExceptionCatalog.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 24/10/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/**
 Use this enum to catalog application-specific **Exceptions** and their corresponding hashlet values.
 */
public enum JRException {
    case cnContactStoreAccessDenied
    case contactAccessDenied
    case emptyContactList
    
    case conversationAlreadyExists
    
    case noCallingCodesForNumber
    case noHashesForNumber
    
    case mismatchedHashAndCallingCode
    case noUserWithCallingCode
    case noUserWithHashes
    case noUserWithPhoneNumber
    case noUsersForContacts
    
    case cannotOpenFile
    case noAudioRecorderToStop
    case noLocalAudioReferenceCopy
    case noSpeechDetected
    case retry
    
    var description: String {
        switch self {
        case .cnContactStoreAccessDenied:
            return "F6E6"
        case .contactAccessDenied:
            return "8F6D"
        case .emptyContactList:
            return "9BAD"
            
        case .conversationAlreadyExists:
            return "CE84"
            
        case .noCallingCodesForNumber:
            return "0BD7"
        case .noHashesForNumber:
            return "452A"
            
        case .mismatchedHashAndCallingCode:
            return "7592"
        case .noUserWithCallingCode:
            return "0E01"
        case .noUserWithHashes:
            return "BD49"
        case .noUserWithPhoneNumber:
            return "C2F1"
        case .noUsersForContacts:
            return "6544"
            
        case .cannotOpenFile:
            return "3C14"; #warning("NEEDS REGENERATION")
        case .noAudioRecorderToStop:
            return "A92A"
        case .noLocalAudioReferenceCopy:
            return "1CD5"
        case .noSpeechDetected:
            return "91C7"
        case .retry:
            return "B386"
        }
    }
}

/**
 Use this extension to add simplified error descriptors and create **Exception** builders for commonly encountered errors.
 */
public extension Exception {
    var userFacingDescriptor: String {
        if let params = extraParams,
           let laymanDescriptor = params["UserFacingDescriptor"] as? String {
            return laymanDescriptor
        }
        
        switch self.descriptor {
        case "Cannot start a conversation with yourself.":
            return "You cannot start a conversation with yourself."
            
        case "Conversation with this user already exists.":
            return "You already have an open conversation with this user."
            
        case "Invalid format.", "The format of the phone number provided is incorrect. Please enter the phone number in a format that can be parsed into E.164 format. E.164 phone numbers are written in the format [+][country code][subscriber number including area code].", "TOO_SHORT", "TOO_LONG":
            return "The format of the phone number provided is incorrect.\n\nPlease verify that you haven't included the country code."
            
        case "No conversation exists with the provided identifier.":
            return "We were unable to retrieve one or more of your conversations.\n\nPlease report this error and try again later."
            
        case "The SMS code has expired. Please re-send the verification code to try again.":
            return "The verification code has expired. Please try again."
            
        case "The SMS verification code used to create the phone auth credential is invalid. Please resend the verification code SMS and be sure to use the verification code provided by the user.":
            return "The verification code entered was invalid. Please try again."
            
        case "Unable to send texts.":
            return "Your device is unable to send text messages."
            
        default:
            return Build.stage == .generalRelease ? "Something went wrong, please try again later." : self.descriptor
        }
    }
}
