//
//  BuildInfoOverlayView.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

public struct BuildInfoOverlayView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @StateObject public var viewModel: BuildInfoOverlayViewModel
    @State public var yOffset: CGFloat = 0
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        VStack {
            sendFeedbackButton
            buildInfoButton
        }
        .offset(x: -10,
                y: yOffset)
        .onShake {
            guard Build.developerModeEnabled else { return }
            DevModeService.presentActionSheet()
        }
    }
    
    //==================================================//
    
    /* MARK: - View Builders */
    
    private var buildInfoButton: some View {
        Button(action: {
            viewModel.presentDisclaimerAlert()
        }, label: {
            Text("\(Build.codeName) \(Build.bundleVersion) (\(String(Build.buildNumber))\(Build.stage.description(short: true)))")
                .font(Font.custom("SFUIText-Bold",
                                  size: 13))
                .foregroundColor(.white)
        })
        .padding(.all, 1)
        .frame(height: 15)
        .background(Color.black)
        .frame(maxWidth: .infinity,
               alignment: .trailing)
        .offset(x: -10)
    }
    
    private var sendFeedbackButton: some View {
        Button(action: {
            viewModel.presentSendFeedbackActionSheet()
        }, label: {
            Text(LocalizedString.sendFeedback)
                .font(Font.custom("Arial",
                                  size: 12))
                .foregroundColor(.white)
                .underline()
        })
        .padding(.horizontal, 1)
        .frame(height: 20)
        .background(Color.black)
        .frame(maxWidth: .infinity,
               alignment: .trailing)
        .offset(x: -10,
                y: 8)
    }
}
