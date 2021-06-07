//
//  TTAService.swift
//  ObjectDetection
//
//  Created by Tomasz Domaracki on 04/06/2021.
//  Copyright © 2021 Y Media Labs. All rights reserved.
//

import Foundation
import CoreImage
import UIKit

struct TTATransform {
  init(boxTransformationProvider: BoxTransformationProvider, transform: CGAffineTransform, reversedTransform: CGAffineTransform) {
    self.boxTransformationProvider = boxTransformationProvider
    self.transform = transform
    self.reversedTransform = reversedTransform
  }
  
  public let boxTransformationProvider: BoxTransformationProvider
  public let transform: CGAffineTransform
  public let reversedTransform: CGAffineTransform
}

struct TTAPrediction {
  init(prediction: PredictionBoxes, ttaTransform: TTATransform) {
    self.prediction = prediction
    self.ttaTransform = ttaTransform
  }
  
  public let prediction: PredictionBoxes
  public let ttaTransform: TTATransform
}

struct TTAService {
  private let HorizontalFlipTransform: CGAffineTransform = CGAffineTransform(scaleX: -1, y: 1)
  private let NegativeScaleTransform: CGAffineTransform = CGAffineTransform(scaleX: -0.2, y: -0.2)
  private let PositiveScaleTransform: CGAffineTransform = CGAffineTransform(scaleX: 0.2, y: 0.2)
  private let NegativeRevScaleTransform: CGAffineTransform = CGAffineTransform(scaleX: -0.1667, y: -0.1667)
  private let PositiveRevScaleTransform: CGAffineTransform = CGAffineTransform(scaleX: 0.25, y: 0.25)
  
  private let predictionInvoker: PredictionInvoker
  private let postProcessor: ModelPostProcessor
  
  init(predictionInvoker: PredictionInvoker, postProcessor: ModelPostProcessor) {
    self.predictionInvoker = predictionInvoker
    self.postProcessor = postProcessor
  }
  
  
  func findBetterPrediction(forImage: CVPixelBuffer, withPrediction: PredictionBoxes) -> PredictionBoxes? {
    let predictions: [TTAPrediction] = transformations()
      .map { transfrom in
        // let uiimage = UIImage(ciImage: CIImage(cvPixelBuffer: forImage))
        let transformedBuffer = processImageAfterTransformation(transform: transfrom.transform, imagePixelBuffer: forImage)
        
        // let uiimage2 = UIImage(ciImage: CIImage(cvPixelBuffer: transformedBuffer))
        guard let out = predictionInvoker.invoke(scaledPixelBuffer: transformedBuffer) else {
          return nil
        }
        guard let prediction = postProcessor.invoke(modelOut: out) else {
          return nil
        }
        
        return TTAPrediction(prediction: prediction, ttaTransform: transfrom)
      }
      .compactMap{ $0 }
    
//    var bestPrediction: PredictionBoxes? = nil
//    var ttaTransform: TTATransform!
//    predictions.forEach { p in
//      let predictionScore = calculateScoresAverage(scores: p.prediction.probabilities)
//      let bestPredictionScore = calculateScoresAverage(scores: (bestPrediction != nil ? bestPrediction! : withPrediction).probabilities)
//      if true {
//        bestPrediction = p.prediction
//        ttaTransform = p.ttaTransform
//      }
//    }
//    if let newBestPrediction = bestPrediction {
//      return ttaTransform.boxTransformationProvider.transform(box: newBestPrediction)
//    }
    return nil
  }
  
  private func processImageAfterTransformation(transform: CGAffineTransform, imagePixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
    var pxBuffer: CVPixelBuffer!
    let pxBufferResult = CVPixelBufferCreate(nil, CVPixelBufferGetWidth(imagePixelBuffer), CVPixelBufferGetHeight(imagePixelBuffer), CVPixelBufferGetPixelFormatType(imagePixelBuffer), nil, &pxBuffer)
    assert(pxBufferResult == kCVReturnSuccess);
    
    let img = CIImage(cvPixelBuffer: imagePixelBuffer)
    
    let halfImageWidth = CGFloat(CVPixelBufferGetWidth(imagePixelBuffer) / 2)
    let halfImageHeight = CGFloat(CVPixelBufferGetHeight(imagePixelBuffer) / 2)
    
    let transformation = CGAffineTransform(translationX: -halfImageWidth, y: -halfImageHeight)
      .concatenating(transform)
      .concatenating(CGAffineTransform(translationX: halfImageWidth, y: halfImageHeight))
    let transformedImg = img.transformed(by: transformation)
    let ctx = CIContext()
    ctx.render(transformedImg, to: pxBuffer)
    return pxBuffer
  }
  
  private func transformations() -> [TTATransform] {
    return [
      TTATransform(
        boxTransformationProvider: HorizontalBoxTransformation(),
        transform: HorizontalFlipTransform,
        reversedTransform: HorizontalFlipTransform
      ),
//      TTATransform(
//        boxTransformationProvider: BoxTransformation(),
//        transform: NegativeScaleTransform,
//        reversedTransform: PositiveRevScaleTransform
//      ),
//      TTATransform(
//        boxTransformationProvider: BoxTransformation(),
//        transform: HorizontalFlipTransform.concatenating(NegativeScaleTransform),
//        reversedTransform: PositiveRevScaleTransform.concatenating(HorizontalFlipTransform)
//      ),
//      TTATransform(
//        boxTransformationProvider: BoxTransformation(),
//        transform: PositiveScaleTransform,
//        reversedTransform: NegativeRevScaleTransform
//      ),
//      TTATransform(
//        boxTransformationProvider: BoxTransformation(),
//        transform: HorizontalFlipTransform.concatenating(PositiveScaleTransform),
//        reversedTransform: NegativeRevScaleTransform.concatenating(HorizontalFlipTransform)
//      )
    ]
  }
  
  private func calculateScoresAverage(scores: [Float]) -> Float {
    if (scores.count == 0) {
      return 0.0
    }
    
    let sum = scores.reduce(0.0) { r, v in
      return r + v
    }
    return sum / Float(scores.count)
  }
  
}
