//
//  ExceptionCatalog.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 24/10/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

import Foundation

/**
 Use this file to add simplified error descriptors and create **Exception** builders for commonly encountered errors.
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
            
        case "Invalid format.", "The format of the phone number provided is incorrect. Please enter the phone number in a format that can be parsed into E.164 format. E.164 phone numbers are written in the format [+][country code][subscriber number including area code].", "TOO_SHORT":
            return "The format of the phone number provided is incorrect.\n\nPlease verify that you have fully entered your phone number, including the country and area codes."
            
        case "No conversation exists with the provided identifier.":
            return "We were unable to retrieve one or more of your conversations.\n\nPlease report this error and try again later."
            
        case "The SMS code has expired. Please re-send the verification code to try again.":
            return "The verification code has expired. Pleasse try again."
            
        case "The SMS verification code used to create the phone auth credential is invalid. Please resend the verification code sms and be sure use the verification code provided by the user.":
            return "The verification code entered was invalid. Please try again."
            
        case "We have blocked all requests from this device due to unusual activity. Try again later.":
            return "Due to unusual activity, all requests from this device have been temporarily blocked. Please try again later."
        default:
            return self.descriptor
        }
    }
}
