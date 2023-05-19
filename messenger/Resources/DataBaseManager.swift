//
//  DataBaseManager.swift
//  messenger
//
//  Created by Андрей Логвинов on 5/9/23.
//

import Foundation
import FirebaseDatabase

final class DataBaseManager{
    
    static let shared  = DataBaseManager()
    
    private  let database = Database.database().reference()
    
    static func safeEmail(emailAdress: String)-> String{
        var safeEmail = emailAdress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    
    
}

// Mark: - Account Managament
extension DataBaseManager{
    
    public func userExists(with email: String , completion : @escaping((Bool) -> Void)){
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        
        database.child(safeEmail).observeSingleEvent(of: .value, with: {snapshot in
            guard let foundEmail = snapshot.value as? String else {
                completion(false)
                return
            }
            
            completion(true)
        })
    }
    
    public func insertUser(with user : ChatAppUser , completion: @escaping(Bool)-> Void){
        database.child(user.safeEmail).setValue([
            "first_name" : user.firstName,
            "last_name" : user.lastName
        ],withCompletionBlock: {error , _ in
            guard error == nil else {
                print("failer to write to database")
                completion(false)
                return
            }
            
            self.database.child("users").observeSingleEvent(of: .value, with: {snapshot in
                if var usersCollection = snapshot.value as? [[String : String]]{
                    let newElement : [[String : String]] = [
                        ["name" : user.firstName + " " + user.lastName,
                         "email" : user.safeEmail]
                    ]
                    usersCollection.append(contentsOf: newElement)
                    self.database.child("users").setValue(usersCollection, withCompletionBlock: {error , _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
                else{
                    let newCollection : [[String : String]] = [
                        [
                            "name" : user.firstName + " " + user.lastName,
                            "email" : user.safeEmail
                        ]
                    ]
                    
                    self.database.child("users").setValue(newCollection, withCompletionBlock: {error , _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        completion(true)
                    })
                }
            })
            
        })
    }
    
    public func getAllUsers(completion: @escaping (Result<[[String : String]], Error>)->Void){
        database.child("users").observeSingleEvent(of: .value, with:{snapshot in
            guard let value = snapshot.value as? [[String : String]] else {
                completion(.failure(DataBaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
    public enum DataBaseError: Error {
        case failedToFetch
    }
}

extension DataBaseManager {
    
    
    public func createNewConversation(with otherUserEmail : String ,name : String , firstMessage: Message , completion: @escaping(Bool) -> Void){
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
            return
        }
        let safeEmail = DataBaseManager.safeEmail(emailAdress: currentEmail)
        let ref  = database.child("\(safeEmail)")
        ref.observeSingleEvent(of: .value, with: {[weak self] snapshot in
            guard var userNode = snapshot.value as? [String : Any] else {
                completion(false)
                print("user not found")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter?.string(from: messageDate)
            
            var message = ""
            
            switch firstMessage.kind {
                
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            let conversationId = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String : Any] = [
                "id" : conversationId,
                "other_user_email": "\(otherUserEmail)",
                "name": name,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            let recipient_newConversationData: [String : Any] = [
                "id" : conversationId,
                "other_user_email": "\(safeEmail)",
                "name": currentName,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    //append
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                    
                }else{
                    //create
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            })
            
            if var conversations = userNode["conversations"] as? [[String : Any]] {
                
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                ref.setValue(userNode, withCompletionBlock: {[weak self] error , _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationID: conversationId,
                                                     name: name,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                })
            }
            else {
                userNode["conversations"] = [
                    newConversationData
                ]
                
                ref.setValue(userNode, withCompletionBlock: {[weak self] error , _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    
                    self?.finishCreatingConversation(conversationID: conversationId,
                                                     name: name,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                    
                })
            }
        })
        
    }
    
    private func finishCreatingConversation(conversationID : String ,name : String, firstMessage : Message , completion: @escaping(Bool)->Void){
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentUserEmail = DataBaseManager.safeEmail(emailAdress: myEmail)
        
        var message = ""
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter?.string(from: messageDate)
        
        switch firstMessage.kind {
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.MessageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read" : false,
            "name": name
        ]
        let value: [String: Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        
        print("CONVERSATION ID  ==== \(conversationID)")
        database.child("\(conversationID)").setValue(value,
                                                     withCompletionBlock: {error , _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    public func getAllConversation(email: String , completion: @escaping (Result<[Conversation] , Error>) -> Void){
        database.child("\(email)/conversations").observe(.value, with: {snapshot in
            guard let value = snapshot.value as? [[String : Any]] else{
                completion(.failure(DataBaseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap({ dictionary in
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String : Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else{
                    return nil
                }
                
                let latestMessageObject = LatestMessage(date: date,
                                                        text: message,
                                                        isRead: isRead)
                return Conversation(id: conversationId, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject)
            })
            completion(.success(conversations))
        })
    }
    
    public func getAllMessagesForConversation(with id : String , completion: @escaping (Result<[Message] , Error>) -> Void){
        
        database.child("\(id)/messages").observe(.value, with: {snapshot in
            guard let value = snapshot.value as? [[String : Any]] else{
                completion(.failure(DataBaseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap({ dictionary in
                guard let name = dictionary["name"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let messageID = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter?.date(from: dateString),
                      let type = dictionary["type"] as? String else{
                    return nil
                }
                
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageID,
                               sentDate: date,
                               kind: .text(content))
            })
            completion(.success(messages))
        })
    }
    
    public func sendMessage(conversation : String, otherUserEmail: String, name: String, newMessage : Message, completion: @escaping(Bool) -> Void){
        //guard let 
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                    completion(false)
                    return
                }
        database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let strongSelf = self else {
                return
            }
            
            guard var currentMessages = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }
       
        
       
        let messageDate = newMessage.sentDate
        let dateString = ChatViewController.dateFormatter?.string(from: messageDate)
        
        var message = ""
        switch newMessage.kind {
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        let currentUserEmail = DataBaseManager.safeEmail(emailAdress: myEmail)
        
        let newMessageCollection: [String: Any] = [
            "id": newMessage.messageId,
            "type": newMessage.kind.MessageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read" : false,
            "name": name
        ]
        
            currentMessages.append(newMessageCollection)
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages, withCompletionBlock: {error , _ in
                guard error == nil else {
                    completion(false)
                    return
                    
                }
                completion(true)
            })
        })
    }
    
}
struct ChatAppUser{
    let firstName : String
    let lastName: String
    let emailAddress: String
    
    var safeEmail : String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    var profilePictureFileNAme : String {
        return "\(safeEmail)_profile_picture.png"
    }
}
extension DataBaseManager {
    
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
            database.child("\(path)").observeSingleEvent(of: .value) { snapshot in
                guard let value = snapshot.value else {
                    completion(.failure(DataBaseError.failedToFetch))
                    return
                }
                completion(.success(value))
            }
        }

}
