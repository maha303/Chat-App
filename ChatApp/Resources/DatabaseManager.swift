//
//  DatabaseManager.swift
//  ChatApp
//
//  Created by Maha saad on 02/06/1443 AH.
//

import Foundation

import FirebaseDatabase
//import FirebaseMLModelDownloader

final class DatabaseManager{
    static let shared = DatabaseManager()
    private let database = Database.database().reference()
    
    static func safeEmail (emailAddress : String) -> String {
       
            var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
            safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
            return safeEmail
    }
}
extension DatabaseManager {
    public func getDataFor(path:String,completion:@escaping(Result<Any,Error>)->Void){
        self.database.child("\(path)").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
}

//Mark: - Account Management
extension DatabaseManager {
    public func userExists(with email : String , completion: @escaping((Bool) -> Void)){
        
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        
        database.child(safeEmail).observeSingleEvent(of: .value , with: { snapshot in
            guard snapshot.value as? String != nil else {
                completion(false)
                return
            }
            completion(true)
        })
        
    }
    ///  insert new user to database
    public func insertUser(with user : ChatAppUser , completion :@escaping (Bool)-> Void){
    database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
    ], withCompletionBlock: { error , _ in
        
        guard error == nil else {
            
            print("failed to write to database ")
            completion(false)
            return
        }
        
        self.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
            if var usersCollection = snapshot.value as? [[String: String]]{
                //append to user
                let newElement = [
                    "name": user.firstName + " " + user.lastName,
                    "email": user.safeEmail
                ]
                usersCollection.append(newElement)
                
                self.database.child("users").setValue(usersCollection ,withCompletionBlock: { error , _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    completion(true)
                    
                })
            }
            else {
                // ceart that array
                let newCollection : [[String : String]] = [
                    [
                        "name": user.firstName + " " + user.lastName,
                        "email": user.safeEmail
                    ]
                ]
                self.database.child("users").setValue(newCollection ,withCompletionBlock: { error , _ in
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
    public func getAllUsers(comletion:@escaping (Result<[[String : String]], Error>)-> Void){
        database.child("users").observeSingleEvent(of: .value, with: {snapshot in
            guard let value = snapshot.value as? [[String:String]] else {
                comletion(.failure(DatabaseError.failedToFetch))
                return
            }
            comletion(.success(value))
            
        })
    }
    public enum DatabaseError : Error {
        case failedToFetch
    }

    /*
     users =>[
     [
     "name":
     "safe_email":
     ],
     [
     "name":
     "safe_email":
       ]
     ]
     */
}

extension DatabaseManager {
    //create new conversation with target user emaml and frist message sent
    public func createNewConversation(with otherUserEmail : String , name:String, fristMessage:Message , completion: @escaping (Bool)->Void){
        
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String ,
        let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child("\(safeEmail)")
        
        ref.observeSingleEvent(of: .value, with: { [weak self]snapshot in
            guard var userNode = snapshot.value as? [String : Any] else {
                completion(false)
                print("user not found")
                return
            }
            let messageDate = fristMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            switch fristMessage.kind{
         
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
            let conversationId = "conversation_\(fristMessage.messageId)"
            
            let newConversationData : [String : Any ] =  [
                "id": conversationId,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message":[
                    "date": dateString ,
                    "message":message,
                    "is_read": false
                ]
            ]
            let recipient_newConversationData : [String : Any ] =  [
                "id": conversationId,
                "other_user_email": safeEmail,
                "name": currentName ,
                "latest_message":[
                    "date": dateString ,
                    "message":message,
                    "is_read": false
                ]
            ]
            
            //update recipient conversation entry
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value , with: {[weak self] snapshot in
                if var conversations = snapshot.value as? [[String : Any]] {
                  //append
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversationId)

                }else {
                    //create
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
                
                
            })
            
            //update currrent user conversations entry
            
            if var conversations = userNode["conversations"] as? [[String : Any]] {
                
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                ref.setValue(userNode, withCompletionBlock: { [weak self]error , _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name : name ,conversationId: conversationId, firstMessage: fristMessage, completion: completion)
                    
                })
                //
            }else {
                //
                userNode["conversations"] = [
                    newConversationData
                ]
                ref.setValue(userNode, withCompletionBlock: {[weak self] error , _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name : name , conversationId: conversationId, firstMessage: fristMessage, completion: completion)
                    
                })
            }
        })
        
    }
    private func finishCreatingConversation(name : String ,conversationId : String , firstMessage : Message , completion : @escaping (Bool)-> Void){
        //{
     //   "id": String,
     //   "type":text , photo , video,
    //    "content":String,
   //     "date":Date(),
    //    "sender_email": String,
   //     "isRead":true/false
        //}
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        var message = ""
        switch firstMessage.kind{
     
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
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        let collectionMessage : [String : Any] = [
            "id": firstMessage.messageId,
            "type" : firstMessage.kind.messageKindString,
            "content" : message,
            "data" :dateString,
            "sender_email" : currentUserEmail,
            "is_read": false,
            "name" : name
        ]
        let value : [String : Any ] = [
            "message": [
                collectionMessage
            ]
        ]
        print("adding convo : \(conversationId)")
        database.child("\(conversationId)").setValue(value, withCompletionBlock: {error , _ in
            guard error == nil else {
                completion(false)
                return
                
            }
            completion(true)
        })
        
 }
    
    public func getAllConversations(for email:String, completion:@escaping(Result<[Conversation],Error>) -> Void){
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String : Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let conversations : [Conversation] = value.compactMap({ dictionary in
                
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String ,
                      let latestMessage = dictionary["latest_message"] as? [String : Any ] ,
                      let date = latestMessage["date"] as? String ,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else {
                          return nil
                      }
                
                let latestMessageObject = LatestMessage(date: date ,
                                                        text: message,
                                                        isRead: isRead)
       return Conversation(id: conversationId,
                           name: name,
                           otherUserEmail: otherUserEmail,
                           latesMessage: latestMessageObject)
            })
            completion(.success(conversations))
        })
        
    }
    public func getAllMessageForConversation(with id: String , complation: @escaping(Result<[Message],Error>) -> Void) {
        database.child("\(id)/message").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String : Any]] else {
                
                complation(.failure(DatabaseError.failedToFetch))
                
                return
            }
            
            let messages : [Message] = value.compactMap({ dictionary in
                
                guard let name = dictionary["name"] as? String,
                   //   let isRead = dictionary["is_read"] as? Bool,
                      let messageID = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String ,
                      let senderEmail = dictionary["sender_email"] as? String,
                    //  let type = dictionary["type"] as? String,
                      let dateString = dictionary["data"] as? String ,
                      let data = ChatViewController.dateFormatter.date(from: dateString)
                    else {
                          return nil
                      }
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageID,
                               sentDate: data,
                               kind: .text(content))
      
            })
            
            complation(.success(messages))
            
        })
        
    }
    
    public func sendMessage(to conversation:String,otherUserEmail: String ,name:String,newMessage:Message,complation: @escaping(Bool)-> Void){
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            complation(false)
            return
        }
        let currentEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        database.child("\(conversation)/message").observeSingleEvent(of: .value, with: {[weak self]snapshot in
            guard let strongSelf = self else {
                return
            }
            guard var currentMessages = snapshot.value as? [[String  : Any ]] else {
                complation(false)
                return
            }
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
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
            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                complation(false)
                return
            }
            let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
            let newMessageEntry : [String : Any] = [
                "id": newMessage.messageId,
                "type" : newMessage.kind.messageKindString,
                "content" : message,
                "data" :dateString,
                "sender_email" : currentUserEmail,
                "is_read": false,
                "name" : name
            ]
            currentMessages.append(newMessageEntry)
            strongSelf.database.child("\(conversation)/message").setValue(currentMessages, withCompletionBlock: { error , _ in
                guard error == nil else {
                    complation(false)
                    return
                }
                
                strongSelf.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    guard var currentUserConversations = snapshot.value as? [[String : Any]] else {
                        complation(false)
                        return
                    }
                    let updatedValue : [String : Any ] = [
                        "date":dateString,
                        "is_read":false,
                        "message":message
                    ]
                    var targetConversation : [String : Any]?
                    var position = 0
                    for conversationDictionary in currentUserConversations {
                        if let currentId = conversationDictionary["id"] as? String , currentId == conversation {
                            targetConversation = conversationDictionary
                            break
                        }
                        position += 1
                    }
                    
                    targetConversation?["latest_message"] = updatedValue
                    guard let finalConversation = targetConversation else {
                        complation(false)
                        return
                    }

                    currentUserConversations[position] = finalConversation
                    strongSelf.database.child("\(currentEmail)/conversations").setValue(currentUserConversations, withCompletionBlock: {error , _ in
                        guard error == nil else {
                            complation(false)
                            return
                        }
                        
                        //update latest message of recipient user
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                            guard var otherUserConversations = snapshot.value as? [[String : Any]] else {
                                complation(false)
                                return
                            }
                            let updatedValue : [String : Any ] = [
                                "date":dateString,
                                "is_read":false,
                                "message":message
                            ]
                            var targetConversation : [String : Any]?
                            var position = 0
                            for conversationDictionary in otherUserConversations {
                                if let currentId = conversationDictionary["id"] as? String , currentId == conversation {
                                    targetConversation = conversationDictionary
                                    break
                                }
                                position += 1
                            }
                            
                            targetConversation?["latest_message"] = updatedValue
                            guard let finalConversation = targetConversation else {
                                complation(false)
                                return
                            }

                            otherUserConversations[position] = finalConversation
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(otherUserConversations, withCompletionBlock: {error , _ in
                                 
                                guard error == nil else {
                                    complation(false)
                                    return
                                }
                             
                                complation(true)
                            })
         
                        })
                    })
                    
                })
                
            })
        
        })
    }
    
}

struct ChatAppUser{
    
    let firstName : String
    let lastName : String
    let emailAddress : String
    var profilePictureFileName : String {
       return "\(safeEmail)_profile_picture.png"
    }
    
    var safeEmail : String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}
