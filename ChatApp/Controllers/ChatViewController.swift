//
//  ChatViewController.swift
//  ChatApp
//
//  Created by Maha saad on 02/06/1443 AH.
//

import UIKit
import MessageKit
import InputBarAccessoryView

struct Message : MessageType {
    public   var sender : SenderType
    public   var messageId: String
    public   var sentDate: Date
    public   var kind: MessageKind
}
extension MessageKind {
    var messageKindString: String{
        switch self {
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
            return "link_preview"
        case .custom(_):
            return "custom"
        }
    }
}

struct Sender :SenderType{
    public  var photoURL : String
    public  var senderId: String
    public var displayName: String
 
}


class ChatViewController: MessagesViewController {
    
    public static let dateFormatter: DateFormatter = {
        
        let formattre = DateFormatter()
        formattre.dateStyle = .medium
        formattre.timeStyle = .long
        formattre .locale = .current
        return formattre
        
    }()
    
    public let otherUserEmail : String
    private let conversationID : String?
    public var isNewConversation = false
    
    private var messages = [Message]()
    
    private var selfSender : Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
      return  Sender(photoURL: "",
               senderId: safeEmail ,
               displayName: "Me")
        
    }
  
    init(with email : String, id: String?) {
        self.conversationID = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
        
       

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self

    }
    
    private func listenForMessages(id: String , shouldScrollToBottom: Bool){
        DatabaseManager.shared.getAllMessageForConversation(with: id, complation: { [weak self] result in
            switch result {
            case .success(let messages):
                guard !messages.isEmpty else{
                    return
                }
                self?.messages = messages
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    if shouldScrollToBottom{
                    self?.messagesCollectionView.scrollToLastItem()
                    }
                }
            case .failure( let error):
                print("failed to get messages:\(error)")
            }
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        
        if let conversationID = conversationID {
            listenForMessages(id: conversationID, shouldScrollToBottom: true)
        }

    }
}
extension ChatViewController : InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty ,
        let selfSender = self.selfSender ,
        let messageId = createMessageId() else{
            return
        }
        print("sending\(text)")
        //send message
        let message = Message(sender: selfSender,
                               messageId: messageId,
                               sentDate: Date(),
                               kind: .text(text))
        if isNewConversation {
            // create convo
          
            DatabaseManager.shared.createNewConversation(with: otherUserEmail, name: self.title ?? "User" , fristMessage: message, completion: { [weak self] success in
                
                if success {
                    print("message sent")
                    self?.isNewConversation = false
                }else{
                    print("faield to send")
                }
                
            })
        }
        else {
            guard let conversationID = conversationID , let name = self.title else {
                return
            }
            //append to existing conversation data
            DatabaseManager.shared.sendMessage(to: conversationID, otherUserEmail: otherUserEmail , name: name ,newMessage: message, complation: {success in
                if success {
                    print("message sent")
                }else {
                    print("failed to send")
                }
            })
        }
    }
    
    private func createMessageId() -> String? {
        
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        let dateString = Self.dateFormatter.string(from: Date())
        let newIdentifier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"
        print("created message id : \(newIdentifier)")
        return newIdentifier
    }
    
}

extension ChatViewController :  MessagesDataSource , MessagesLayoutDelegate , MessagesDisplayDelegate {
    func currentSender() -> SenderType {
        
        if let sender = selfSender {
            return sender
        }
        fatalError("Self Sender is nil , email should be cached")
        
      //  return Sender(photoURL: "", senderId: "12", displayName: "")
        
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
        
    }
    
    
}
