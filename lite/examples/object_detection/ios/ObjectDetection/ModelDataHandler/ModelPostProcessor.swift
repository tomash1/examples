//
//  ModelPostProcessor.swift
//  ObjectDetection
//
//  Created by Tomasz Domaracki on 31/05/2021.
//  Copyright © 2021 Y Media Labs. All rights reserved.
//

import Foundation
import CoreImage
import Matft

struct SlicedPredictions {
    private let probabilities: MfArray
    private let confidence: MfArray
    private let boxesDelta: MfArray
    
    init(probabilities: MfArray, confidence: MfArray, boxesDelta: MfArray) {
        self.probabilities = probabilities
        self.confidence = confidence
        self.boxesDelta = boxesDelta
    }
}

struct ModelPostProcessor {
    private static let PredMatrixShape: [Int] = [1, 14400, 7]
    
    private let config: SqueezeConfigWithAnchors?
    
    init() {
        let c = SqueezeConfig.fromFile(fileName: "squeeze", fileExtension: "config")
        guard let config = c else {
            print("Unable to invoke post process - SqueezeConfig was not loaded.")
            self.config = nil
            return
        }
        self.config = SqueezeConfigWithAnchors(config: config)
    }
    
    func invoke(outData: [Float], imageWidth: CGFloat, imageHeight: CGFloat) {
        guard let config = self.config else {
            print("Unable to invoke post process - SqueezeConfig was not loaded.")
            return
        }
        let r = slicePredictions(detections: outData, config: config)
    }
    
    private func slicePredictions(detections: [Float], config: SqueezeConfigWithAnchors) -> SlicedPredictions {
        var predictionsMatrix = MfArray(detections)
            .reshape(ModelPostProcessor.PredMatrixShape)
        
        let outsCount = config.c.CLASSES + 1 + 4
        predictionsMatrix = predictionsMatrix[0~<, 0~<, 0~<outsCount]
        
        predictionsMatrix = predictionsMatrix.reshape([config.c.ANCHORS_HEIGHT, config.c.ANCHORS_WIDTH, -1])
        let classesCount = config.c.ANCHOR_PER_GRID * config.c.CLASSES
        
        
        let predictionProbabilities = predictionsMatrix[0~<, 0~<, 0~<classesCount]
            .reshape([-1, config.c.CLASSES])
            .softmax()
            .reshape([config.anchorsCount, config.c.CLASSES])
        
        let confidenceScoresCount = config.c.ANCHOR_PER_GRID + classesCount
        let predictionConfidence = predictionsMatrix[0~<, 0~<, classesCount~<confidenceScoresCount]
            .reshape([config.anchorsCount])
            .sigmoid()
        
        let predictionBoxDelta = predictionsMatrix[0~<, 0~<, confidenceScoresCount~<predictionsMatrix[1].size]
            .reshape([config.anchorsCount, 4])
        
        return SlicedPredictions(probabilities: predictionProbabilities, confidence: predictionConfidence, boxesDelta: predictionBoxDelta)
    }
}

extension MfArray {
    func softmax(axis: Int = 1) -> MfArray {
        let ex = Matft.math.exp(self - Matft.stats.max(self))
        let sum = Matft.stats.sum(ex, axis: axis, keepDims: false)
        let expanded = Matft.expand_dims(sum, axis: axis)
        return ex / expanded
    }
    
    func sigmoid() -> MfArray {
        return 1 / (1 + Matft.math.exp(-self))
    }
}
