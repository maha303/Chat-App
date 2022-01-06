//
//  NewConversationViewController.swift
//  ChatApp
//
//  Created by Maha saad on 02/06/1443 AH.
//

import UIKit
import JGProgressHUD

class NewConversationViewController: UIViewController {
    public var completion:(([String : String]) -> (Void ))?
       
       private let spinner = JGProgressHUD(style: .dark)
       private var users = [[String : String]]()
       private var results = [[String : String]]()

       private var hasFetched = false
       
       private let searchBar : UISearchBar = {
           let searchBar = UISearchBar()
           searchBar.placeholder = "Search for Users ..."
           return searchBar
       }()
       private let tableView : UITableView = {
          let table = UITableView()
           table.isHidden = true
           table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
           return table
       }()
       private let noResultsLabel :UILabel  = {
          let lable = UILabel()
           lable.isHidden = true
           lable.text = "No Resulte"
           lable.textAlignment = .center
           lable.textColor = .green
           lable.font = .systemFont(ofSize: 21 , weight : .medium)
           return lable
       }()

       override func viewDidLoad() {
           super.viewDidLoad()
           view.addSubview(noResultsLabel)
           view.addSubview(tableView)
           tableView.delegate = self
           tableView.dataSource = self
           searchBar.delegate = self
           view.backgroundColor = .white
           navigationController?.navigationBar.topItem?.titleView = searchBar
           navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel",
                                                               style: .done,
                                                               target: self,
                                                               action: #selector(dismissSelf))
           searchBar.becomeFirstResponder()
      
       }
       override func viewDidLayoutSubviews() {
           super.viewDidLayoutSubviews()
           tableView.frame = view.bounds
           noResultsLabel.frame = CGRect(x: view.width/4, y: (view.height-200)/2, width: view.width/2, height: 200)
       }
       
       @objc private func dismissSelf(){
           dismiss(animated: true, completion: nil)
       }

   }
   extension NewConversationViewController : UITableViewDelegate , UITableViewDataSource {
       func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
           return results.count
       }

       func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
           let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
           cell.textLabel?.text = results[indexPath.row]["name"]
           return cell
       }
       func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
           tableView.deselectRow(at: indexPath, animated: true)
           // start conversation
           let targetUserData = results[indexPath.row]
           dismiss(animated: true, completion: {[weak self ] in
               self?.completion?(targetUserData)

           })
           
       }

   }
   extension NewConversationViewController : UISearchBarDelegate {
       
       
       
       func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
           
           guard let text = searchBar.text, !text.replacingOccurrences(of: " ", with: "").isEmpty else {
               return
           }
           searchBar.resignFirstResponder()
           results.removeAll()
           spinner.show(in: view)
           self.searchUsers(query: text)
           
       }
       
       func searchUsers(query : String){
           //check if array has firebase result
           if hasFetched {
               //if it dose : filter
               filterUsers(with: query)

           }else{
               //if not : fetch then filter
               DatabaseManager.shared.getAllUsers(comletion: {[weak self] result in
                   switch result {
                   case .success(let usersColletion):
                       self?.hasFetched = true
                       self?.users = usersColletion
                       self?.filterUsers(with: query)
                   case .failure(let error):
                       print("Failed to get users : \(error)")
                   }
               })
           }
       }
       func filterUsers(with term : String){
           //update the ui either show result or show no result lable
           guard hasFetched else {
               return
           }
           self.spinner.dismiss()
           
           let results : [[String : String]] = self.users.filter({
               guard let name = $0["name"]?.lowercased() else {
                   return false
               }
               
               return name.hasPrefix(term.lowercased())
           })
           self.results = results
           updateUI()
       }
       
       func updateUI(){
           
           if results.isEmpty {
               self.noResultsLabel.isHidden = false
               self.tableView.isHidden = true
           }
           else {
               self.noResultsLabel.isEnabled = true
               self.tableView.isHidden = false
               self.tableView.reloadData()
           }
       }
}
