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
    case conversationWithYourself
    
    case failedToRetranslate
    case operationTimedOut
    
    case invalidVerificationCode
    case verificationCodeExpired
    
    case noCallingCodesForNumber
    case noHashesForNumber
    
    case noContactArchive
    case noTranslationsForLanguagePair
    
    case mismatchedHashAndCallingCode
    case noUserWithCallingCode
    case noUserWithHashes
    case noUserWithPhoneNumber
    case noUsersForContacts
    
    case numberInvalidFormat
    case numberTooLong
    case numberTooShort
    
    case cannotOpenFile
    case noAudioRecorderToStop
    case noLocalAudioReferenceCopy
    case noSpeechDetected
    case retry
    
    case noReadDate
    
    var description: String {
        switch self {
        case .cnContactStoreAccessDenied:
            return "0865"
        case .contactAccessDenied:
            return "8F6D"
        case .emptyContactList:
            return "9BAD"
            
        case .conversationAlreadyExists:
            return "CE84"
        case .conversationWithYourself:
            return "F8E5"
            
        case .failedToRetranslate:
            return "1BC2"
        case .operationTimedOut:
            return "DE75"
            
        case .invalidVerificationCode:
            return "0A84"
        case .verificationCodeExpired:
            return "F623"
            
        case .noCallingCodesForNumber:
            return "0BD7"
        case .noHashesForNumber:
            return "452A"
            
        case .noContactArchive:
            return "897E"
        case .noTranslationsForLanguagePair:
            return "7CDC"
            
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
            
        case .numberInvalidFormat:
            return "470A"
        case .numberTooLong:
            return "B5B4"
        case .numberTooShort:
            return "3E46"
            
        case .cannotOpenFile:
            return "3C14"
        case .noAudioRecorderToStop:
            return "A92A"
        case .noLocalAudioReferenceCopy:
            return "1CD5"
        case .noSpeechDetected:
            return "11B6"
        case .retry:
            return "7983"
            
        case .noReadDate:
            return "947F"
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
            return "The format of the phone number provided is incorrect.\n\nPlease verify that you have fully entered your phone number, including the area code."
            
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
