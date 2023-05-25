//
//  ConversationsModels.swift
//  messenger
//
//  Created by Андрей Логвинов on 5/25/23.
//

import Foundation

struct Conversation {
    let id: String
    let name: String
    let otherUserEmail : String
    let latestMessage: LatestMessage
}

struct LatestMessage {
    let date: String
    let text: String
    let isRead: Bool
    
}
