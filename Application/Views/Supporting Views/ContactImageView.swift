//
//  ContactImageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 22/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

public struct ContactImageView: View {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    public var uiImage: UIImage?
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        if let image = uiImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .font(.system(size: 50))
                .frame(width: 50, height: 50)
                .cornerRadius(10)
                .clipShape(Circle())
                .padding(.top, 10)
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 50))
                .frame(width: 50, height: 50)
                .cornerRadius(10)
                .foregroundColor(Color.gray)
                .padding(.top, 10)
        }
    }
}
