//
//  StorageManager.swift
//  ChatApp
//
//  Created by Maha saad on 02/06/1443 AH.
//

import Foundation
import FirebaseStorage


final class StorageManager {
    
    static let shared = StorageManager()
    private let storage = Storage.storage().reference()
    
    /*
     /image/maha-hotmail-com_profile_pic.png
     */
    
    ///Uploads pic to firebase and reture url
    
    public typealias UploadPictureCompletion = (Result<String,Error>) -> Void
    
    public func uploadProfilePicture(with data : Data ,fileName : String ,completion: @escaping UploadPictureCompletion) {
        storage.child("images/\(fileName)").putData(data, metadata: nil , completion: { metadata , error in
            
            guard error == nil else {
                // failed
                print("failed to upload data to firebase for picture ")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
        })
        self.storage.child("images/\(fileName)").downloadURL(completion:{ url , error in
            guard let url = url else {
                print("Failed to get download url")
                completion(.failure(StorageErrors.failedToGetDownloadUrl))
                return
            }
            let urlString = url.absoluteString
            print("download url returned : \(urlString)")
            completion(.success(urlString))
        })
    }
    public enum StorageErrors : Error {
        case failedToUpload
        case failedToGetDownloadUrl
        
    }
    public func downloadURL(for path : String ,completion :  @escaping  (Result<URL,Error>)-> Void){
        
        let reference = storage.child(path)
        reference.downloadURL(completion: { url , error in
            
            guard let url = url , error == nil else {
                completion(.failure(StorageErrors.failedToGetDownloadUrl))
                return
            }
            completion(.success(url))
        })
        
    }
}
