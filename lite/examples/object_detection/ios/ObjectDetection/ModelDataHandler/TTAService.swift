//
//  TTAService.swift
//  ObjectDetection
//
//  Created by Tomasz Domaracki on 04/06/2021.
//  Copyright © 2021 Y Media Labs. All rights reserved.
//

import Foundation
import CoreImage

struct TTAService {
  private let HorizontalFlipTransform: CGAffineTransform = CGAffineTransform(scaleX: -1, y: 1)
  private let NegativeScaleTransform: CGAffineTransform = CGAffineTransform(scaleX: -0.2, y: -0.2)
  private let PositiveScaleTransform: CGAffineTransform = CGAffineTransform(scaleX: 0.2, y: 0.2)
  private let NegativeRevScaleTransform: CGAffineTransform = CGAffineTransform(scaleX: -0.1667, y: -0.1667)
  private let PositiveRevScaleTransform: CGAffineTransform = CGAffineTransform(scaleX: 0.25, y: 0.25)
  
  
  func findBestPrediction(forImage: CVPixelBuffer, withPrediction: PredictionBoxes) -> PredictionBoxes? {
    let img = CIImage(cvPixelBuffer: forImage)
    img.transformed(by: transformations()[0])
    let ctx = CIContext()
    ctx.render(img, to: forImage)
    
    return nil
  }
  
  private func transformations() -> [CGAffineTransform] {
    return [
      HorizontalFlipTransform,
      NegativeScaleTransform,
      HorizontalFlipTransform.concatenating(NegativeScaleTransform),
      PositiveScaleTransform,
      HorizontalFlipTransform.concatenating(PositiveScaleTransform)
    ]
  }
  
  private func reversedTransformations() -> [CGAffineTransform] {
    return [
      HorizontalFlipTransform,
      PositiveRevScaleTransform,
      PositiveRevScaleTransform.concatenating(HorizontalFlipTransform),
      NegativeRevScaleTransform,
      NegativeRevScaleTransform.concatenating(HorizontalFlipTransform)
    ]
  }
  
}
