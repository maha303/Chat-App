//
//  LoginViewController.swift
//  ChatApp
//
//  Created by Maha saad on 02/06/1443 AH.
//

import UIKit
import Firebase
import JGProgressHUD
import FacebookLogin

class LoginViewController: UIViewController {
    private let spinner = JGProgressHUD(style: .dark)
    private let scrollView : UIScrollView = {
            let scrollView = UIScrollView()
            scrollView.clipsToBounds = true
            return scrollView

        }()
       private let imageView : UIImageView = {
           let imageView = UIImageView()
           imageView.image = UIImage(named: "logo")
           imageView.contentMode = .scaleAspectFit
           return imageView
       }()
    private let emailField : UITextField = {
           let field = UITextField()
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.returnKeyType = .continue
            field.layer.cornerRadius = 12
            field.layer.borderWidth = 1
            field.layer.borderColor = UIColor.lightGray.cgColor
            field.placeholder = "Email Address..."
            field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
            field.leftViewMode = .always
            field.backgroundColor = .white
            return field
        }()
        
        private let passwordField : UITextField = {
           let field = UITextField()
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.returnKeyType = .done
            field.layer.cornerRadius = 12
            field.layer.borderWidth = 1
            field.layer.borderColor = UIColor.lightGray.cgColor
            field.placeholder = "Password ..."
            field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
            field.leftViewMode = .always
            field.backgroundColor = .white
            field.isSecureTextEntry = true
            return field
        }()
    private let loginButton : UIButton = {
          let button = UIButton()
           button.setTitle("Log In", for: .normal)
           button.backgroundColor = .link
           button.setTitleColor(.white, for: .normal)
           button.layer.cornerRadius = 12
           button.layer.masksToBounds = true
           button.titleLabel?.font = .systemFont(ofSize: 20 , weight : .bold)
           return button
       }()
    private let facebookLoginButton : FBLoginButton = {
          let button = FBLoginButton()
          button.permissions = ["public_profile", "email"]
         return button
       }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Login"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Register", style: .done, target: self, action: #selector(didTapRegister))
        loginButton.addTarget(self,
                                      action: #selector(loginButtonTapped),
                                      for: .touchUpInside)
                
                emailField.delegate = self
                passwordField.delegate = self
                facebookLoginButton.delegate = self
        //Add subviews
        view.addSubview(scrollView)
                scrollView.addSubview(imageView)
                scrollView.addSubview(emailField)
                scrollView.addSubview(passwordField)
                scrollView.addSubview(loginButton)
                scrollView.addSubview(facebookLoginButton)

        // Do any additional setup after loading the view.
    }
    override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            scrollView.frame = view.bounds
            let size = scrollView.width/3
            imageView.frame = CGRect(x:(scrollView.width-size)/2,
                                     y:20,
                                     width: size,
                                     height: size)
            emailField.frame = CGRect(x:30,
                                      y:imageView.bottom+10,
                                      width: scrollView.width-60,
                                     height: 52)
            passwordField.frame = CGRect(x:30,
                                      y:emailField.bottom+10,
                                      width: scrollView.width-60,
                                     height: 52)
            loginButton.frame = CGRect(x:30,
                                     y: passwordField.bottom+10,
                                     width: scrollView.width-60,
                                     height: 52)
            facebookLoginButton.frame = CGRect(x:30,
                                      y: loginButton.bottom+10,
                                      width: scrollView.width-60,
                                    height: 52)
          facebookLoginButton.frame.origin.y = loginButton.bottom+20
        }
    @objc private func loginButtonTapped(){
            emailField.resignFirstResponder()
            passwordField.resignFirstResponder()
            
            guard let email = emailField.text , let password = passwordField.text ,
                  !email.isEmpty , !password.isEmpty , password.count >= 6 else {
                      alerUserLoginError()
                      return
                  }
            spinner.show(in: view)
            //firebase log in
            Auth.auth().signIn(withEmail: email, password: password) { (authResult: AuthDataResult?, error: Error?) in
                
                DispatchQueue.main.async {
                    self.spinner.dismiss()

                }

                if let error = error , authResult == nil{
                    print("error \(error.localizedDescription)")
                }else{
                    let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                    DatabaseManager.shared.getDataFor(path: safeEmail, completion: {  result in
                        switch result {
                        case .success(let data):
                            guard let userData = data as? [String : Any],
                            let firstName = userData["first_name"] as? String,
                            let lastName = userData["last_name"] as? String else {
                                return
                            }
                            UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")

                        case .failure(let error):
                            print("failed to read data with error \(error)")
                        }
                    })
                    UserDefaults.standard.set(email, forKey: "email")

                    
                    print("Done :)")
                    self.navigationController?.dismiss(animated: true, completion: nil)
                }
            }
        }
        func alerUserLoginError(){
            let alert = UIAlertController(title: "Woops", message: "Please enter all information to log in.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
            present(alert, animated: true)
        }

    @objc private func didTapRegister(){
            let vc = RegisterViewController()
            vc.title = "Create Account"
            navigationController?.pushViewController(vc, animated: true)
        }
    
}
extension LoginViewController:UITextFieldDelegate{
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField {
            passwordField.becomeFirstResponder()
        }
        else if textField == passwordField {
            loginButtonTapped()
        }
        return true
    }
    
}
extension LoginViewController : LoginButtonDelegate {
  func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
       // no operation
    }
    
   func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
      guard let tokne = result?.token?.tokenString else {
         print("User failed to log in with facebook")
            return
        }
       let facebookRequest = FBSDKLoginKit.GraphRequest(graphPath: "me",
                                                        parameters: ["fields" : "email, first_name, last_name,picture.type(large)"],
                                                        tokenString: tokne,
                                                        version: nil,
                                                        httpMethod: .get)
       facebookRequest.start(completionHandler: { _ , result , error in
           guard let result = result as? [String:Any] , error == nil else {
               print("Failed to make facebook graph request")
               return
           }
           
           print(result)
           guard let firstName = result["first_name"] as? String ,
                 let lastName = result["last_name"] as? String ,
                 let email = result["email"] as? String ,
                 let picture = result["picture"] as? [String : Any],
                 let data = picture["data"] as? [String : Any] ,
                 let pictureUrl = data["url"] as? String else {
                     print("Faield to get email and name from fb result")
                     return
                 }
           
           UserDefaults.standard.set(email, forKey: "email")
           UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")

 
           DatabaseManager.shared.userExists(with: email, completion: { exits in
               if !exits {
                   
                   let chatUser = ChatAppUser(firstName: firstName,
                                              lastName: lastName,
                                              emailAddress: email)
                   
                   DatabaseManager.shared.insertUser(with: chatUser, completion: { success in
                       if success {
                           guard let url = URL(string: pictureUrl) else {
                               return
                           }
                           print("Downloading data from facebook image")
                           URLSession.shared.dataTask(with: url, completionHandler: { data , _ , _ in
                               guard let data = data else {
                                   print("Failed to get data from facebook")
                                   return
                               }
                               print("got data from FB uploading")
                               // upload image
                               let filename = chatUser.profilePictureFileName
                               StorageManager.shared.uploadProfilePicture(with: data, fileName: filename, completion: {result in
                                   switch result {
                                   case .success(let downloadUrl):
                                       UserDefaults.standard.set( downloadUrl , forKey: "profile_picture_url")
                                       print(downloadUrl)
                                   case .failure(let error):
                                       print("Storrage manager error \(error)")
                                   }
                               })
                               
                           }).resume()
                           
                       }
                       
                   })
               }
               
           })
           
           let credential = FacebookAuthProvider.credential(withAccessToken: tokne)
           
           Auth.auth().signIn(with: credential , completion: { [weak self] authResult, error in
               guard let strongSelf = self else{
                   return
               }
               guard authResult != nil , error == nil else {
                   if let error = error {
                       print("Facebook login failed , MFA may be needed - \(error)")
                   }
                  
                   return
               }
              print("successfully logged user in")
               strongSelf.navigationController?.dismiss(animated: true, completion: nil)
           })

       })
   
    }
    
}





