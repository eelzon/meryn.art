//
//  RibbonCollectionViewController.swift
//  collects.art
//
//  Created by Nozlee Samadzadeh on 4/16/17.
//  Copyright © 2017 Nozlee Samadzadeh and Bunny Rogers. All rights reserved.
//

import UIKit

protocol RibbonDelegate {

  func setUserRibbon()

}

class RibbonCollectionViewCell: UICollectionViewCell {

  @IBOutlet var ribbonView: UIImageView!

}

class RibbonCollectionViewController: UICollectionViewController {

  var ribbon: String! = UserDefaults.standard.object(forKey: "ribbon") as! String
  var ribbons: NSArray! = UserDefaults.standard.object(forKey: "ribbons") as! NSArray
  var delegate: RibbonDelegate!

  override func viewWillAppear(_ animated: Bool) {
    self.view?.superview?.layer.cornerRadius = 0
    super.viewWillAppear(animated)
  }

  // MARK: UICollectionViewDataSource

  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }

  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return ribbons.count
  }

  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RibbonCollectionViewCell", for: indexPath) as! RibbonCollectionViewCell

    let url = ribbons.object(at: indexPath.row) as! String
    cell.ribbonView.af_setImage(withURL: URL(string: url)!)

    cell.layer.borderWidth = 1.0
    cell.layer.cornerRadius = 0
    if url == ribbon {
      cell.layer.borderColor = UIColor.gray.cgColor
    } else {
      cell.layer.borderColor = UIColor.clear.cgColor
    }

    return cell
  }

  // MARK: UICollectionViewDelegate

  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    ribbon = ribbons.object(at: indexPath.row) as! String
    UserDefaults.standard.set(ribbon, forKey: "ribbon")
    delegate.setUserRibbon()
  }

}
