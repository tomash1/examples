//
//  ResultsViewController.swift
//  ObjectDetection
//
//  Created by Tomasz Domaracki on 06/06/2021.
//  Copyright © 2021 Y Media Labs. All rights reserved.
//

import UIKit

class ResultsViewController: UIViewController {
  @IBOutlet weak var sendAsTextView: UITextField!
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
  public var frameImage: UIImage?
  public var latitude: Double?
  public var longitude: Double?
  public var inferenceTime: Double?
  public var dangerDegree: String?
  
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
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd.MM.yyyy'T'HH:mm:ss"
    
    sendImageButton.isEnabled = false
    let smokePrediction = SmokePrediction(
      created_date: dateFormatter.string(from: Date()),
      user_id: sendAsTextView.text!,
      frame: frameImage != nil ? "\(frameImage!.size.height)x\(frameImage!.size.width)" : nil,
      crop: resultImage != nil ? "\(resultImage!.size.height)x\(resultImage!.size.width)" : nil,
      inference_time: inferenceTime != nil ? "\(Int(inferenceTime!)) ms" : nil,
      final_threshold: "0.6",
      gpu: "0",
      tta: "0",
      jpg: getResultImageAsBase64(),
      danger_degree: dangerDegree,
      location: "\(latitude ?? 0.0),\(longitude ?? 0.0)"
    )
    
    let encoder = JSONEncoder()
    do {
      let data = try encoder.encode(smokePrediction)
      HttpService().send(json: data) { d in
        self.performSegue(withIdentifier: "UnwindToMainView", sender: nil)
      }
    } catch {
      print("Cannot convert \(error.localizedDescription)")
    }
    sendImageButton.isEnabled = true
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
        self.view.frame.origin.y = -keyboardSize.height
      }
  }
  
  private func getResultImageAsBase64() -> String? {
    guard let image = resultImage else {
      return nil
    }
    
    let imgJpegData = image.jpegData(compressionQuality: 1)
    return imgJpegData?.base64EncodedString()
  }
}
