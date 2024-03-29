//
//  AvatarImageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 22/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

public struct AvatarImageView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public var uiImage: UIImage?
    public var dimensions: CGSize?
    public var size: CGFloat?
    public var includePadding = true
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        if let image = uiImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .font(.system(size: size ?? 50))
                .frame(width: dimensions?.width ?? 50, height: dimensions?.height ?? 50)
                .cornerRadius(10)
                .clipShape(Circle())
                .padding(.top, includePadding ? 10 : 0)
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: size ?? 50))
                .frame(width: dimensions?.width ?? 50, height: dimensions?.height ?? 50)
                .cornerRadius(10)
                .foregroundColor(Color.gray)
                .padding(.top, includePadding ? 10 : 0)
        }
    }
}
