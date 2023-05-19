//
//  ChatViewController.swift
//  messenger
//
//  Created by Андрей Логвинов on 5/10/23.
//

import UIKit
import MessageKit
import InputBarAccessoryView

struct Message : MessageType {
    public var sender: SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind
    
}

extension MessageKind {
    var MessageKindString: String {
        switch self{
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributed_text"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "link"
        case .custom(_):
            return "custom"
        }
    }
    }

struct Sender : SenderType {
    public var photoURL: String
    public var senderId: String
    public var displayName: String
}

class ChatViewController: MessagesViewController {
    
    public static var dateFormatter: DateFormatter? = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = Locale(identifier: "en_US") 
        return formatter
    }()
    
    public var isNewConversation = false
    public var otherUserEmail: String
    public var conversationId: String?
    private var messages = [Message]()
    
    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        
        let safeEmail = DataBaseManager.safeEmail(emailAdress: email)
        let path = "images/\(safeEmail)_profile_picture.png"
        return Sender(photoURL: "",
               senderId: safeEmail ,
               displayName: "Me")}
    
    
    

    
    init(with email : String, id : String?){
        self.conversationId = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationId = conversationId {
            self.conversationId = conversationId
            listenForMessages(id: conversationId, shouldScrollToBottom: true)
        }
    }
    
    private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
        DataBaseManager.shared.getAllMessagesForConversation(with: id, completion: { [weak self] result in
            switch result{
            case .success(let messages):
                guard !messages.isEmpty else{ return }
                self?.messages = messages
                
                DispatchQueue.main.async {
                    if shouldScrollToBottom{
                        self?.messagesCollectionView.reloadDataAndKeepOffset()
                        self?.messagesCollectionView.scrollToBottom()
                    }
                }
            case .failure(let error):
                print("faile to get messages: \(error)")
            }
            
        })
    }

}

extension ChatViewController : InputBarAccessoryViewDelegate{
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
           guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
               let selfSender = self.selfSender,
               let messageId = createMessageId() else {
                   return
           }

           print("Sending: \(text)")

           let mmessage = Message(sender: selfSender,
                                  messageId: messageId,
                                  sentDate: Date(),
                                  kind: .text(text))

           // Send Message
           if isNewConversation {
               // create convo in database
               DataBaseManager.shared.createNewConversation(with: otherUserEmail, name: self.title ?? "User", firstMessage: mmessage, completion: { [weak self]success in
                   if success {
                       print("message sent")
                       self?.isNewConversation = false
                       let newConversationId = "conversation_\(mmessage.messageId)"
                       self?.conversationId = newConversationId
                       self?.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
                       self?.messageInputBar.inputTextView.text = nil
                   }
                   else {
                       print("faield ot send")
                   }
               })
           }
           else {
               guard let conversationId = conversationId, let name = self.title else {
                   return
               }

               
               DataBaseManager.shared.sendMessage(conversation: conversationId,
                                                  otherUserEmail: otherUserEmail,
                                                  name: name,
                                                  newMessage: mmessage,
                                                  completion: { [weak self] success in
                   if success {
                       self?.messageInputBar.inputTextView.text = nil
                       print("message sent")
                   }
                   else {
                       print("failed to send")
                   }
               })
           }
       }
    
    private func createMessageId()-> String?{
        
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let dateString = Self.dateFormatter?.string(from: Date()) else {
            return nil
        }
        let safeCurrrentEmail = DataBaseManager.safeEmail(emailAdress: currentUserEmail)
        let newIdentifier = "\(otherUserEmail)_\(safeCurrrentEmail)_\(dateString)"
        print("CREATED MESSAGE ID _ \(newIdentifier)")
        return newIdentifier
    }
}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate{
    
    func currentSender() -> SenderType {
        return selfSender!
       
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessageKit.MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
        return messages.count
    }
    
    
}
