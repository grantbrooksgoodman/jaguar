//
//  PermissionService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 04/03/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import AVFoundation
import Contacts
import Foundation
import Speech
import UIKit
import UserNotifications

/* Third-party Frameworks */
import AlertKit

public enum PermissionType {
    case contacts
    case notifications
    case recording
    case transcription
}

public enum PermissionStatus {
    case granted
    case denied
    case unknown
}

public protocol PermissionServiceable {
    static func requestPermission(for type: PermissionType, completion: @escaping(PermissionStatus, Exception?) -> Void)
}

public struct PermissionService: PermissionServiceable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static var contactPermissionStatus: PermissionStatus { get { getContactPermissionStatus() } }
    public static var recordPermissionStatus: PermissionStatus { get { getRecordPermissionStatus() } }
    public static var transcribePermissionStatus: PermissionStatus { get { getTranscribePermissionStatus() } }
    
    //==================================================//
    
    /* MARK: - Permission Requesting */
    
    public static func requestPermission(for type: PermissionType, completion: @escaping (_ status: PermissionStatus,
                                                                                          _ exception: Exception?) -> Void) {
        switch type {
        case .contacts:
            requestContactPermission { status, exception in
                completion(status, exception)
            }
        case .notifications:
            requestNotificationPermission { status, exception in
                completion(status, exception)
            }
        case .recording:
            requestRecordPermission { status, exception in
                completion(status, exception)
            }
        case .transcription:
            requestTranscribePermission { status, exception in
                completion(status, exception)
            }
        }
    }
    
    private static func requestContactPermission(completion: @escaping(_ status: PermissionStatus,
                                                                       _ exception: Exception?) -> Void) {
        CNContactStore().requestAccess(for: .contacts) { granted, error in
            guard error == nil else {
                let exception = Exception(error!, metadata: [#file, #function, #line])
                guard exception.isEqual(to: .cnContactStoreAccessDenied) else {
                    completion(.unknown, exception)
                    return
                }
                
                completion(.denied, nil)
                return
            }
            
            completion(granted ? .granted : .denied, nil)
        }
    }
    
    private static func requestNotificationPermission(completion: @escaping(_ status: PermissionStatus,
                                                                            _ exception: Exception?) -> Void) {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            guard granted else {
                completion(error == nil ? .denied : .unknown,
                           error == nil ? nil : Exception(error!, metadata: [#file, #function, #line]))
                return
            }
            
            completion(.granted, nil)
        }
    }
    
    private static func requestRecordPermission(completion: @escaping(_ status: PermissionStatus,
                                                                      _ exception: Exception?) -> Void) {
        let sharedAudioSession = AVAudioSession.sharedInstance()
        do {
            try sharedAudioSession.setCategory(.playAndRecord, mode: .default)
            try sharedAudioSession.setActive(true)
            
            sharedAudioSession.requestRecordPermission { granted in
                guard granted else {
                    completion(.denied, nil)
                    return
                }
                
                completion(.granted, nil)
            }
        } catch { completion(.unknown, Exception(error, metadata: [#file, #function, #line])) }
    }
    
    private static func requestTranscribePermission(completion: @escaping(_ status: PermissionStatus,
                                                                          _ exception: Exception?) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                completion(.granted, nil)
            case .denied, .restricted:
                completion(.denied, nil)
            case .notDetermined:
                completion(.unknown, nil)
            @unknown default:
                completion(.unknown, Exception("Failed to get transcription permission.",
                                               metadata: [#file, #function, #line]))
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Call-to-Action Methods */
    
    public static func presentCTA(for type: PermissionType,
                                  sender: UIView? = nil,
                                  completion: @escaping() -> Void) {
        switch type {
        case .contacts:
            presentContactCTA(sender: sender) { completion() }
        case .notifications:
            presentNotificationCTA(sender: sender) { completion() }
        case .recording:
            presentRecordCTA(sender: sender) { completion() }
        case .transcription:
            presentTranscribeCTA(sender: sender) { completion() }
        }
    }
    
    private static func presentContactCTA(sender: UIView?, completion: @escaping() -> Void) {
        presentCTA(withMessage: "*Hello* has not been granted permission to access your contact list.\n\nYou can change this in Settings.",
                   sender: sender) { cancelled in
            if !cancelled {
                StateProvider.shared.tappedDone = true
            }
            completion()
        }
    }
    
    private static func presentNotificationCTA(sender: UIView?, completion: @escaping() -> Void) {
        presentCTA(withMessage: "*Hello* has not been granted permission to send and receive notifications.\n\nYou can change this in Settings.",
                   sender: sender) { _ in completion() }
    }
    
    private static func presentRecordCTA(sender: UIView?, completion: @escaping() -> Void) {
        presentCTA(withMessage: "*Hello* needs access to your microphone to record audio messages.\n\nYou can grant this permission in Settings.",
                   sender: sender) { _ in completion() }
    }
    
    private static func presentTranscribeCTA(sender: UIView?, completion: @escaping() -> Void) {
        presentCTA(withMessage: "*Hello* needs speech recognition access to translate audio messages.\n\nYou can grant this permission in Settings.",
                   sender: sender) { _ in completion() }
    }
    
    private static func presentCTA(withMessage: String,
                                   sender: UIView?,
                                   completion: @escaping(_ cancelled: Bool) -> Void) {
        let settingsUrl = URL(string: UIApplication.openSettingsURLString)
        
        var actions = [AKAction]()
#if !EXTENSION
        if let settingsUrl,
           UIApplication.shared.canOpenURL(settingsUrl) {
            actions.append(AKAction(title: LocalizedString.settings, style: .default))
        }
#endif
        
        var message = withMessage
        message = RuntimeStorage.languageCode == "en" ? message.removingOccurrences(of: ["*"]) : message
        
        let ctaAlert = AKAlert(message: message,
                               actions: actions.isEmpty ? nil : actions,
                               cancelButtonTitle: LocalizedString.dismiss,
                               sender: sender,
                               shouldTranslate: [.message])
        
        ctaAlert.present { actionID in
            guard actionID != -1 else { completion(true); return }
            guard actionID == ctaAlert.actions.first(where: { $0.title == LocalizedString.settings })?.identifier,
                  let settingsUrl else { completion(false); return }
            
#if !EXTENSION
            UIApplication.shared.open(settingsUrl)
#endif
            completion(false)
        }
    }
    
    //==================================================//
    
    /* MARK: - Permission Status Getters */
    
    private static func getContactPermissionStatus() -> PermissionStatus {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
    
    public static func getNotificationPermissionStatus(completion: @escaping(_ status: PermissionStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .ephemeral, .provisional:
                completion(.granted)
            case .denied:
                completion(.denied)
            case .notDetermined:
                completion(.unknown)
            @unknown default:
                completion(.unknown)
            }
        }
    }
    
    private static func getRecordPermissionStatus() -> PermissionStatus {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
    
    private static func getTranscribePermissionStatus() -> PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
}
