/*
 * Copyright (c) 2015 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import RealmSwift

class Dog: Object {
  dynamic var name = ""
  dynamic var age = 0
}

class Person: Object {
  dynamic var name = ""
  dynamic var picture: NSData? = nil
  let dogs = List<Dog>()
}

class GroceryListTableViewController: UITableViewController {

  // MARK: Constants
  let listToUsers = "ListToUsers"
  
  // MARK: Properties 
  var items: [GroceryItem] = []
  var user: User!
  var userCountBarButtonItem: UIBarButtonItem!
  
  let ref = FIRDatabase.database().reference(withPath: "grocery-items")
  let usersRef = FIRDatabase.database().reference(withPath: "online")
  

  
  
  
  // MARK: UIViewController Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.allowsMultipleSelectionDuringEditing = false
    
    userCountBarButtonItem = UIBarButtonItem(title: "1",
                                             style: .plain,
                                             target: self,
                                             action: #selector(userCountButtonDidTouch))
    userCountBarButtonItem.tintColor = UIColor.white
    navigationItem.leftBarButtonItem = userCountBarButtonItem
    
    user = User(uid: "FakeId", email: "hungry@person.food")

    let myDog: Dog = Dog()
    myDog.name = "Rex"
    myDog.age = 1
    
    let realm  = try! Realm()
    
    let puppies = realm.objects(Dog.self).filter("age < 2")
    print("=======> \(puppies.count)")
    
    try! realm.write {
      realm.add(myDog)
    }
    
    print("=======> \(puppies.count)")
    
    DispatchQueue(label: "background").async {
      let realm = try! Realm()
      let theDog = realm.objects(Dog.self).filter("age == 1").first
      try! realm.write {
        theDog!.age = 3
      }
    }
    // Retrive data from Firebase
//    ref.observe(.value, with: {
//      snapshot in
//      // 2
//      var newItems: [GroceryItem] = []
//      
//      // 3
//      for item in snapshot.children {
//        // 4
//        let groceryItem = GroceryItem(snapshot: item as! FIRDataSnapshot)
//        newItems.append(groceryItem)
//      }
//      
//      // 5
//      self.items = newItems
//      self.tableView.reloadData()
//    })
    ref.queryOrdered(byChild: "completed").observe(.value, with: { snapshot in
      var newItems: [GroceryItem] = []
      
      for item in snapshot.children {
        let groceryItem = GroceryItem(snapshot: item as! FIRDataSnapshot)
        newItems.append(groceryItem)
      }
      
      self.items = newItems
      self.tableView.reloadData()
      
    })
    
    usersRef.observe(.value, with: { snapshot in
      if snapshot.exists() {
        self.userCountBarButtonItem?.title = snapshot.childrenCount.description
      } else {
        self.userCountBarButtonItem?.title = "0"
      }
    })
    
    FIRAuth.auth()!.addStateDidChangeListener({ (auth, user) in
      guard let user = user else { return }
      self.user = User(authData: user)
      
      // 1
      let currentUserRef = self.usersRef.child(self.user.uid)
      // 2
      currentUserRef.setValue(self.user.email)
      // 3
      currentUserRef.onDisconnectRemoveValue()
    })
  }
  
  // MARK: UITableView Delegate methods
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return items.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath)
    let groceryItem = items[indexPath.row]
    
    cell.textLabel?.text = groceryItem.name
    cell.detailTextLabel?.text = groceryItem.addedByUser
    
    toggleCellCheckbox(cell, isCompleted: groceryItem.completed)
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      let groceryItem = items[indexPath.row]
      groceryItem.ref?.removeValue()
    }
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    // 1 Find the cell the user tapped using cellForRow(at:)
    guard let cell = tableView.cellForRow(at: indexPath) else { return }
    
    // 2 Get the corressponding GroceryItem by using the index path's row.
    let groceryItem = items[indexPath.row]
    
    // 3 Negate completed on the grocry item to toggle the statue
    let toggledCompletion = !groceryItem.completed
    
    // 4 Call toggleCellCheckbox(_:isCompleted:) to update the visual properties of the cell
    toggleCellCheckbox(cell, isCompleted: toggledCompletion)
    
    // 5 Use updateChildValues(_:) passing a dictionary
    groceryItem.ref?.updateChildValues([
        "completed": toggledCompletion
      ])
  
  }
  
  func toggleCellCheckbox(_ cell: UITableViewCell, isCompleted: Bool) {
    if !isCompleted {
      cell.accessoryType = .none
      cell.textLabel?.textColor = UIColor.black
      cell.detailTextLabel?.textColor = UIColor.black
    } else {
      cell.accessoryType = .checkmark
      cell.textLabel?.textColor = UIColor.gray
      cell.detailTextLabel?.textColor = UIColor.gray
    }
  }
  
  // MARK: Add Item
  
  @IBAction func addButtonDidTouch(_ sender: AnyObject) {
    let alert = UIAlertController(title: "Grocery Item",
                                  message: "Add an Item",
                                  preferredStyle: .alert)
    
    let saveAction = UIAlertAction(title: "Save", style: .default) { (_) in
      // 1
      // Get the text field from the alert controller
      guard let textField = alert.textFields?.first,
        let text = textField.text else {return}
      
      // 2
      // Using the current user's data, create a new GroceryItem that is not completed by default
      let groceryItem = GroceryItem(name: text, addedByUser: self.user.email, completed: false)
      
      // 3
      // Create a child reference using child(_:). The key value of this reference is the item;s name in
      // lowercase, so when users add duplicate items
      let groceryItemRef = self.ref.child(text.lowercased())
      
      // 4
      // Use setValue(_:) to save data to the database. This method expects a dictionary. called toAnyObject() to turn it into a Dictionary.
      groceryItemRef.setValue(groceryItem.toAnyObject())
    }
    
//    let saveAction = UIAlertAction(title: "Save",
//                                   style: .default) { action in
//      let textField = alert.textFields![0] 
//      let groceryItem = GroceryItem(name: textField.text!,
//                                    addedByUser: self.user.email,
//                                    completed: false)
//      self.items.append(groceryItem)
//      self.tableView.reloadData()
//    }
    
    let cancelAction = UIAlertAction(title: "Cancel",
                                     style: .default)
    
    alert.addTextField()
    
    alert.addAction(saveAction)
    alert.addAction(cancelAction)
    
    present(alert, animated: true, completion: nil)
  }
  
  func userCountButtonDidTouch() {
    performSegue(withIdentifier: listToUsers, sender: nil)
  }
  
}
