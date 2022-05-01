//
//  MainPageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

//==================================================//

/* MARK: - Views */

public struct MainPageView: View {
    @StateObject public var viewModel: MainPageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear(perform: viewModel.load)
        case .loading:
            ProgressView("Loading...")
        case .loaded(let translations):
            Image(uiImage: UIImage(named: "Hello.png")!)
                .resizable()
                .frame(width: 150, height: 70)
                .padding(.bottom, 5)
            
            Text(translations["instruction"]!.output)
                .padding(.vertical, 5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            Button {
                viewRouter.currentPage = .signUp_phoneNumber
            } label: {
                Text(translations["continue"]!.output)
                    .bold()
            }
            .padding(.vertical, 5)
            .foregroundColor(.blue)
        case .failed(let errorDescriptor):
            Text(errorDescriptor)
        }
    }
}

public struct TitleSubtitleView: View {
    @State public var translations: [String: Translation]
    
    public var body: some View {
        VStack(alignment: .leading) {
            Text(translations["title"]!.output)
                .bold()
                .font(.title)
                .padding(.bottom, 2)
                .minimumScaleFactor(0.01)
            
            Text(translations["subtitle"]!.output)
                .foregroundColor(.gray)
                .font(.system(size: 14))
                .minimumScaleFactor(0.01)
        }
        .frame(width: UIScreen.main.bounds.width / 2, height: 200, alignment: .topLeading)
        .padding(.trailing, UIScreen.main.bounds.width / 2)
        .padding(.leading, 40)
        .padding(.top, 15)
    }
}
