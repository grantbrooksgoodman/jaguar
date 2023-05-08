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
    
    @State private var forceAppearanceUpdate = UUID()
    @ObservedObject private var stateProvider = StateProvider.shared
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        VStack {
            Group {
                sendFeedbackButton
                buildInfoButton
            }
            .id(forceAppearanceUpdate)
        }
        .offset(x: -10,
                y: yOffset)
        .onShake {
            guard Build.developerModeEnabled else { return }
            DevModeService.presentActionSheet()
        }
        .onChange(of: stateProvider.developerModeEnabled) { _ in
            forceAppearanceUpdate = UUID()
        }
    }
    
    //==================================================//
    
    /* MARK: - View Builders */
    
    private var buildInfoButton: some View {
        Button(action: {
            viewModel.presentDisclaimerAlert()
        }, label: {
            if Build.developerModeEnabled {
                Circle()
                    .foregroundColor(dotColor)
                    .frame(width: 8, height: 8, alignment: .trailing)
                    .padding(.trailing, -6)
            }
            
            Text("\(Build.codeName) \(Build.bundleVersion) (\(String(Build.buildNumber))\(Build.stage.description(short: true)))")
                .font(Font.custom("SFUIText-Bold", size: 13))
                .foregroundColor(.white)
        })
        .padding(.all, 1)
        .frame(height: 15)
        .background(Color.black)
        .frame(maxWidth: .infinity,
               alignment: .trailing)
        .offset(x: -10)
    }
    
    private var dotColor: Color {
        switch GeneralSerializer.environment {
        case .development:
            return .green
        case .staging:
            return .orange
        case .production:
            return .red
        }
    }
    
    private var sendFeedbackButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
