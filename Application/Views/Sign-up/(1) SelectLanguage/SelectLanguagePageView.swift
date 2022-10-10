//
//  SelectLanguagePageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/**
 Authenticates and signs the user in;
 generates Firebase UID.
 */
public struct SelectLanguagePageView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @StateObject public var viewModel: SelectLanguagePageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    @State private var selectedLanguage: String = RuntimeStorage.languageCodeDictionary![RuntimeStorage.languageCode!]!
    
    public var languages = Array(RuntimeStorage.languageCodeDictionary!.values).sorted()
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear {
                RuntimeStorage.store(Locale.preferredLanguages[0].components(separatedBy: "-")[0],
                                     as: .languageCode)
                viewModel.load()
            }
        case .loading:
            ProgressView("" /*"Loading..."*/)
        case .loaded(let translations):
            VStack {
                TitleSubtitleView(translations: translations)
                
                VStack(alignment: .center) {
                    Text(translations["instruction"]!.output)
                        .bold()
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                        .padding(.vertical, 5)
                    
                    Picker("", selection: $selectedLanguage) {
                        ForEach(languages, id: \.self) {
                            Text($0)
                        }
                    }
                    //                .pickerStyle(.wheel)
                    .padding(.horizontal, 30)
                    
                    Button {
                        RuntimeStorage.store(RuntimeStorage.languageCodeDictionary!.allKeys(forValue: selectedLanguage).first!,
                                             as: .languageCode)
                        viewRouter.currentPage = .signUp_verifyNumber
                    } label: {
                        Text(translations["continue"]!.output)
                            .bold()
                    }
                    .padding(.top, 5)
                    .foregroundColor(.blue)
                    
                    Button {
                        viewRouter.currentPage = .initial
                    } label: {
                        Text(translations["back"]!.output)
                    }
                    .padding(.top, 2)
                    .foregroundColor(.blue)
                    .font(.system(size: 15))
                }
                .padding(.top, 50)
                
                Spacer()
            }.onAppear { RuntimeStorage.store(#file, as: .currentFile) }
        case .failed(let errorDescriptor):
            Text(errorDescriptor)
        }
    }
}
