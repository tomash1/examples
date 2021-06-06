//
//  ResultsViewController.swift
//  ObjectDetection
//
//  Created by Tomasz Domaracki on 06/06/2021.
//  Copyright © 2021 Y Media Labs. All rights reserved.
//

import UIKit

class ResultsViewController: UIViewController {
  @IBOutlet weak var sendAsTextView: UITextView!
  @IBOutlet weak var userNameView: UIView!
  @IBOutlet weak var resultImageView: UIImageView!
  @IBOutlet weak var sendImageButton: UIButton!
  
  public var resultImage: UIImage? {
    get {
      return resultImageView.image
    }
    set {
      resultImageView.image = newValue
    }
  }
  
  private var userNameViewY: CGFloat!
  
  override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)

      NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(notification:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)

      NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    
    let gesture = UITapGestureRecognizer(target: self, action:  #selector(self.viewTouched))
    self.view.addGestureRecognizer(gesture)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
      super.viewWillDisappear(animated)

      NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
      NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
  }
  
  @IBAction func sendButtonClicked(sender: AnyObject) {
    performSegue(withIdentifier: "UnwindToMainView", sender: nil)
  }
  
  @IBAction func textEditDone(_ sender: UITextField) {
    sender.resignFirstResponder()
  }
  
  @objc func viewTouched() {
    view.endEditing(true)
  }
  
  @objc func keyboardWillHide() {
      self.view.frame.origin.y = 0
  }

  @objc func keyboardWillChange(notification: NSNotification) {

      if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
//          if userNameView.isFirstResponder {
              self.view.frame.origin.y = -keyboardSize.height
//          }
      }
  }
}
