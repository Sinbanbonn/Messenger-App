//
//  ProfileViewModel.swift
//  messenger
//
//  Created by Андрей Логвинов on 5/20/23.
//

import Foundation

enum ProfileViewModelType {
    case info, logout
}

struct ProfileViewModel {
    let viewModelType: ProfileViewModelType
    let title: String
    let handler: (() -> Void)?
}
