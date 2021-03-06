//
//  CollectViewController.swift
//  collects.art
//
//  Created by Nozlee Samadzadeh on 4/6/17.
//  Copyright © 2017 Nozlee Samadzadeh and Bunny Rogers. All rights reserved.
//

import UIKit
import Firebase
import AlamofireImage
import SDCAlertView
import SESlideTableViewCell

protocol CollectDelegate {

  func updateCollect(timestamp: String, collect: NSDictionary)

}

class CollectTitleTableViewCell: UITableViewCell {

  @IBOutlet var titleLabel: UILabel!

}

class CollectWithImageTableViewCell: SESlideTableViewCell {

  @IBOutlet var titleLabel: UILabel!
  @IBOutlet var entryImageView: UIImageView!

}

class CollectTableViewCell: SESlideTableViewCell {

  @IBOutlet var titleLabel: UILabel!

}

class CollectViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIPopoverPresentationControllerDelegate, UIAdaptivePresentationControllerDelegate, SESlideTableViewCellDelegate, TemplateDelegate, EntryDelegate, UIGestureRecognizerDelegate {

  @IBOutlet var tableView: UITableView!
  @IBOutlet var backButton: UIBarButtonItem!
  @IBOutlet var openButton: UIBarButtonItem!
  @IBOutlet var renameButton: UIBarButtonItem!
  @IBOutlet var templateButton: UIBarButtonItem!
  @IBOutlet var addButton: UIBarButtonItem!
  @IBOutlet var activityIndicator: UIActivityIndicatorView!

  let font = UIFont(name: "Times New Roman", size: 18)!
  var uid: String = FIRAuth.auth()!.currentUser!.uid
  var entryTimestamps: NSMutableArray! = NSMutableArray()
  var entries: NSMutableDictionary! = NSMutableDictionary()
  var readonly: Bool = false
  var ref: FIRDatabaseReference = FIRDatabase.database().reference()
  var storageRef: FIRStorageReference! = FIRStorage.storage().reference()
  var timestamp: String!
  var collectTitle: String!
  var collect: NSDictionary!
  var delegate: CollectDelegate!
  var slidOpenIndexPath: IndexPath!

  // MARK: UIViewController

  override func viewDidLoad() {
    super.viewDidLoad()

    getEntries()

    let swipeToCollects = UISwipeGestureRecognizer(target: self, action: #selector(backToCollects(_:)))
    swipeToCollects.direction = .right
    swipeToCollects.delegate = self
    view.addGestureRecognizer(swipeToCollects)

    backButton.customView = CollectsButton(image: "back", target: self, action: #selector(backToCollects(_:)))
    openButton.customView = CollectsButton(image: "open", target: self, action: #selector(openCollect(_:)))
    renameButton.customView = CollectsButton(image: "rename", target: self, action: #selector(renameCollect(_:)))
    templateButton.customView = CollectsButton(image: "template", target: self, action: #selector(openTemplate(_:)))
    addButton.customView = CollectsButton(image: "add", target: self, action: #selector(createEntry(_:)))

    tableView.scrollsToTop = true
    tableView.rowHeight = UITableViewAutomaticDimension
    tableView.estimatedRowHeight = 140
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
  }

  // MARK: UIAdaptivePresentationControllerDelegate

  func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
    return .none
  }

  // MARK: UIGestureRecognizerDelegate

  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    // if we catch a right swipe gesture but there's an open slide menu under that swipe, ignore the swipe gesture
    // in favor of the pan gesture to close the slide menu
    if (gestureRecognizer as? UISwipeGestureRecognizer) != nil,
      let indexPath = tableView.indexPathForRow(at: gestureRecognizer.location(in: view)),
      let cell = tableView.cellForRow(at: indexPath) as? SESlideTableViewCell,
      cell.slideState == SESlideTableViewCellSlideState.right {
      return false
    }
    return true
  }

  // MARK: UITableViewDataSource

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      return 1
    } else {
      return entryTimestamps.count
    }
  }

  func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == 0 {
      let cell = tableView.dequeueReusableCell(withIdentifier: "CollectTitleTableViewCell") as! CollectTitleTableViewCell
      cell.titleLabel?.text = collectTitle
      return cell
    } else {
      let entryTimestamp = entryTimestamps[indexPath.row] as! String
      let entry = entries.value(forKey: entryTimestamp) as! NSDictionary
      var entryTitle: String
      if let title = entry.value(forKey: "title") as? String, title.characters.count > 0 {
        entryTitle = title
      } else {
        entryTitle = "untitled"
      }

      var cell: SESlideTableViewCell
      if let imageURL = entry.object(forKey: "image") as? String, imageURL.characters.count > 0 {
        cell = tableView.dequeueReusableCell(withIdentifier: "CollectWithImageTableViewCell") as! CollectWithImageTableViewCell
        (cell as! CollectWithImageTableViewCell).entryImageView.af_setImage(withURL: URL(string: imageURL)!)
        (cell as! CollectWithImageTableViewCell).titleLabel?.text = entryTitle
      } else {
        cell = tableView.dequeueReusableCell(withIdentifier: "CollectTableViewCell") as! CollectTableViewCell
        (cell as! CollectTableViewCell).titleLabel?.text = entryTitle
      }

      if !readonly {
        cell.removeAllRightButtons()
        cell.delegate = self
        cell.showsRightSlideIndicator = false
        cell.addRightButton(withText: "delete", textColor: UIColor.white, backgroundColor: UIColor.gray, font: font)
      }
      return cell
    }
  }

  // MARK: UITableViewDelegate

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    // if there's any open slide menu, close it before moving
    if slidOpenIndexPath != nil,
      let slidOpenCell = tableView.cellForRow(at: slidOpenIndexPath) as? SESlideTableViewCell {
      slidOpenCell.setSlideState(SESlideTableViewCellSlideState.center, animated: false)
    }
  }

  // MARK: SESlideTableViewCellDelegate

  func slideTableViewCell(_ cell: SESlideTableViewCell!, didTriggerRightButton buttonIndex: NSInteger) {
    let indexPath = tableView.indexPath(for: cell)!
    let entryTimestamp = entryTimestamps[indexPath.row] as! String

    let entry = entries.object(forKey: entryTimestamp) as! NSDictionary
    ref.child("collects/\(timestamp!)/entries/\(entryTimestamp)").removeValue()
    entryTimestamps.removeObject(at: indexPath.row)
    entries.removeObject(forKey: entryTimestamp)

    if let filename = entry.value(forKey: "filename") as? String {
      let task = storageRef.child("images/\(filename)")
      task.delete(completion: { error in
        if let error = error {
          print(error.localizedDescription)
        }
      })
    }

    tableView.reloadData()
  }

  func slideTableViewCell(_ cell: SESlideTableViewCell!, wilShowButtonsOf side: SESlideTableViewCellSide) {
    let indexPath = tableView.indexPath(for: cell)!
    // if there's a previously opened slide menu in another cell, close it
    if slidOpenIndexPath != nil,
      indexPath != slidOpenIndexPath,
      let slidOpenCell = tableView.cellForRow(at: slidOpenIndexPath) as? SESlideTableViewCell {
      slidOpenCell.setSlideState(SESlideTableViewCellSlideState.center, animated: true)
    }
    slidOpenIndexPath = indexPath
  }

  // MARK: collect

  func renameCollect(_ button: UIButton) {
    // close popovers if open
    dismiss(animated: true, completion: {})
    let alert = AlertController(title: "", message: "", preferredStyle: .alert)
    alert.addTextField(withHandler: { (textField) -> Void in
      textField.autocapitalizationType = .none
      textField.text = self.collect.value(forKey: "title") as? String
    })
    alert.add(AlertAction(title: "Cancel", style: .normal))
    alert.add(AlertAction(title: "Rename", style: .normal, handler: { [weak alert] (action) -> Void in
      let textField = alert!.textFields![0] as UITextField
      if (textField.text?.characters.count)! > 0 {
        self.changeTitle(textField.text!)
      }
    }))
    alert.visualStyle = CollectsAlertVisualStyle(alertStyle: .alert)
    alert.present()
  }

  func openCollect(_ sender: Any) {
    // close popovers if open
    dismiss(animated: true, completion: {})
    if timestamp != nil, let title = collect.value(forKey: "title") {
      let url = ("https://collectable.art/\(timestamp!)/\(title)" as NSString).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
      UIApplication.shared.openURL(URL(string: url)!)
    }
  }

  func changeTitle (_ title: String!) {
    collectTitle = title
    collect.setValue(title, forKey: "title")

    tableView.beginUpdates()
    tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
    tableView.endUpdates()

    delegate.updateCollect(timestamp: timestamp, collect: collect)

    self.ref.child("users/\(uid)/collects/\(timestamp!)/title").setValue(title)
    self.ref.child("collects/\(timestamp!)/title").setValue(title)
  }

  // MARK: entries

  func getEntries() {
    activityIndicator.startAnimating()
    openButton.isEnabled = false
    addButton.isEnabled = false
    templateButton.isEnabled = false
    renameButton.isEnabled = false
    ref.child("collects/\(timestamp!)").observeSingleEvent(of: .value, with: { (snapshot) in
      if snapshot.exists() {
        if let value = snapshot.value as? NSDictionary {
          self.activityIndicator.stopAnimating()
          if let entries = value.object(forKey: "entries") as? NSDictionary {
            self.entries = entries.mutableCopy() as! NSMutableDictionary
            let array = (self.entries.allKeys as! [String]).sorted { $1.localizedCaseInsensitiveCompare($0) == ComparisonResult.orderedAscending } as NSArray
            self.entryTimestamps = NSMutableArray(array: array)
          }
          if (value.object(forKey: "readonly") as? NSNumber) == 1 {
            self.readonly = true
            self.addButton.isEnabled = false
            self.templateButton.isEnabled = false
            self.renameButton.isEnabled = false
          } else {
            self.addButton.isEnabled = true
            self.templateButton.isEnabled = true
            self.renameButton.isEnabled = true
          }
          self.collect = value
          self.openButton.isEnabled = true
          self.tableView.reloadData()
        }
      }
    }) { (error) in
      self.activityIndicator.stopAnimating()
      print(error.localizedDescription)
    }
  }

  func createEntry(_ sender: Any) {
    // close popovers if open
    dismiss(animated: true, completion: {})
    let entryTimestamp = "\(Int(NSDate().timeIntervalSince1970))"
    let entry: NSDictionary = ["title": ""]
    ref.child("collects/\(timestamp!)/entries/\(entryTimestamp)").setValue(entry)
    (collect.value(forKey: "entries") as? NSDictionary)?.setValue(entry, forKey: entryTimestamp)
    entries.setValue(entry, forKey: entryTimestamp)
    entryTimestamps.insert(entryTimestamp, at: 0)
    tableView.reloadData()
    performSegue(withIdentifier: "segueToEntry", sender: entryTimestamp)
  }

  func updateEntry(entryTimestamp: String, entry: NSDictionary) {
    entries.setValue(entry, forKey: entryTimestamp)
    tableView.reloadData()
  }

  // MARK: templates

  func openTemplate(_ sender: Any) {
    performSegue(withIdentifier: "segueToTemplates", sender: self)
  }

  func saveTemplate(index: Int) {
    self.dismiss(animated: true, completion: (() -> Void)? {
      self.ref.child("collects/\(self.timestamp!)/template").setValue(index)
      self.collect.setValue(index, forKey: "template")
      self.delegate.updateCollect(timestamp: self.timestamp, collect: self.collect)
      })
  }

  // MARK: segues

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "segueToEntry" {
      var entryTimestamp: String
      var entry: NSDictionary
      if let indexPath = tableView.indexPathForSelectedRow {
        entryTimestamp = entryTimestamps[indexPath.row] as! String
      } else {
        entryTimestamp = sender as! String
      }
      entry = entries.value(forKey: entryTimestamp) as! NSDictionary

      let destination = segue.destination as! EntryViewController
      destination.entry = entry.mutableCopy() as! NSMutableDictionary
      destination.collectTimestamp = timestamp
      destination.timestamp = entryTimestamp
      destination.readonly = readonly
      destination.delegate = self
    } else if segue.identifier == "segueToTemplates" {
      if let destination = segue.destination as? TemplateCollectionViewController {
        destination.popoverPresentationController!.delegate = self
        destination.delegate = self
        destination.preferredContentSize = CGSize(width: 300, height: 300)
        destination.templateIndex = collect.value(forKey: "template") as! Int
      }
    }
  }

  @IBAction func unwindToCollect(segue:UIStoryboardSegue) {

  }

  func backToCollects(_ sender: Any) {
    performSegue(withIdentifier: "unwindToCollects", sender: self)
  }
  
}
