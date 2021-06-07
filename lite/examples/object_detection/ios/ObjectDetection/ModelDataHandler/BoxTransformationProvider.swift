//
//  BoxTransformationProvider.swift
//  ObjectDetection
//
//  Created by Tomasz Domaracki on 07/06/2021.
//  Copyright © 2021 Y Media Labs. All rights reserved.
//

import Foundation
import Matft

protocol BoxTransformationProvider {
  func transform(box: PredictionBoxes) -> PredictionBoxes?
}

struct BoxTransformation: BoxTransformationProvider {
  func transform(box: PredictionBoxes) -> PredictionBoxes? {
    return nil
  }
}

struct HorizontalBoxTransformation: BoxTransformationProvider {
  func transform(box: PredictionBoxes) -> PredictionBoxes? {
    if (box.boxes.count == 0) {
      return nil
    }
    
    let boxes = Matft.hstack(box.boxes).reshape([box.boxes.count, 4])
    var imgCenter = MfArray(Array.init(repeating: 0, count: 480))[0~<, 0~<, -1]/2
    imgCenter = Matft.hstack([imgCenter, imgCenter])
    
    boxes[0~<, 0] += 2 * (imgCenter[0] - boxes[0~<, 0])
    boxes[0~<, 2] += 2 * (imgCenter[2] - boxes[0~<, 2])
    
    let boxW = Matft.math.abs(boxes[0~<, 0] - boxes[0~<, 2])
    
    boxes[0~<, 0] -= boxW
    boxes[0~<, 2] += boxW
    
    var prediction = box
    prediction.boxes = boxes.reshape([box.boxes.count, 4]).toArray() as! [MfArray]
    return prediction
  }
}
