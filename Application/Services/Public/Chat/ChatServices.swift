//
//  ChatServices.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 21/02/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public protocol ChatService {
    var serviceType: ChatServiceType { get set }
}

public enum ChatServiceType {
    case audioMessage
    case chatUI
    case delivery
    case menuController
    case observer
    case retranslation
}

public final class ChatServices {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private(set) static var audioMessageService: AudioMessageService?
    private(set) static var chatUIService: ChatUIService?
    private(set) static var deliveryService: DeliveryService?
    private(set) static var menuControllerService: MenuControllerService?
    private(set) static var observerService: ObserverService?
    private(set) static var retranslationService: RetranslationService?
    
    //==================================================//
    
    /* MARK: - Public Methods */
    
    public static func register(service: ChatService) {
        switch service.serviceType {
        case .audioMessage:
            audioMessageService = service as? AudioMessageService
        case .chatUI:
            chatUIService = service as? ChatUIService
        case .delivery:
            deliveryService = service as? DeliveryService
        case .menuController:
            menuControllerService = service as? MenuControllerService
        case .observer:
            observerService = service as? ObserverService
        case .retranslation:
            retranslationService = service as? RetranslationService
        }
    }
    
    public static func register(services: [ChatService]) {
        for service in services {
            register(service: service)
        }
    }
}


//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: - ChatServices */
public extension ChatServices {
    static var defaultAudioMessageService: AudioMessageService? {
        if audioMessageService == nil {
            guard let messagesVC = RuntimeStorage.messagesVC,
                  let service = try? AudioMessageService(delegate: messagesVC) else { return nil }
            register(service: service)
        }
        
        return audioMessageService
    }
    
    static var defaultChatUIService: ChatUIService? {
        if chatUIService == nil {
            guard let messagesVC = RuntimeStorage.messagesVC else { return nil }
            register(service: ChatUIService(delegate: messagesVC))
        }
        
        return chatUIService
    }
    
    static var defaultDeliveryService: DeliveryService? {
        if deliveryService == nil {
            guard let coordinator = RuntimeStorage.coordinator,
                  let service = try? DeliveryService(delegate: coordinator) else { return nil }
            register(service: service)
        }
        
        return deliveryService
    }
    
    static var defaultMenuControllerService: MenuControllerService? {
        if menuControllerService == nil {
            guard let messagesVC = RuntimeStorage.messagesVC,
                  let service = try? MenuControllerService(delegate: messagesVC) else { return nil }
            register(service: service)
        }
        
        return menuControllerService
    }
    
    /// - Warning: Unused.
    static var defaultObserverService: ObserverService? {
        if observerService == nil {
            guard let service = try? ObserverService() else { return nil }
            register(service: service)
        }
        
        return observerService
    }
    
    static var defaultRetranslationService: RetranslationService? {
        if retranslationService == nil {
            guard let messagesVC = RuntimeStorage.messagesVC,
                  let service = try? RetranslationService(delegate: messagesVC) else { return nil }
            register(service: service)
        }
        
        return retranslationService
    }
}
