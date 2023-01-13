//
//  QuickViewer.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import QuickLook

/* Third-party Frameworks */
import AlertKit

public final class QuickViewer: NSObject, QLPreviewControllerDataSource {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static let shared = QuickViewer()
    
    private var fileName = ""
    
    //==================================================//
    
    /* MARK: - Protocol Compliance */
    
    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    public func previewController(_ controller: QLPreviewController,
                                  previewItemAt index: Int) -> QLPreviewItem {
        return URL(fileURLWithPath: fileName) as QLPreviewItem
    }
    
    //==================================================//
    
    /* MARK: - Public Methods */
    
    public func present(with fileName: String) {
        let previewController = QLPreviewController()
        self.fileName = fileName
        
        previewController.dataSource = self
        
#if targetEnvironment(simulator)
        let exception = Exception("Cannot use QuickLook in Simulator.",
                                  isReportable: false,
                                  metadata: [#file, #function, #line])
        AKErrorAlert(error: exception.asAkError()).present()
#else
        Core.ui.present(viewController: previewController)
#endif
    }
}
