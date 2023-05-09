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
    
    public func insertUser(with user : ChatAppUser){
        database.child(user.safeEmail).setValue([
            "first_name" : user.firstName,
            "last_name" : user.lastName
        ])
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
    //let profilePictureUrl : String
}
