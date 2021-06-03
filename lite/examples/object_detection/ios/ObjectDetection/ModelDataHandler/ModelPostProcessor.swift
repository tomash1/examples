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
    public let probabilities: MfArray
    public let confidence: MfArray
    public let boxesDelta: MfArray
    
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
        let predictions = slicePredictions(detections: outData, config: config)
        let detBoxes = boundingBoxesFromDeltas(deltas: predictions.boxesDelta, config: config)
        let probs = Matft.mul(predictions.probabilities, predictions.confidence.reshape([config.anchorsCount, 1]))
        let detProbs = Matft.stats.max(probs, axis: 1, keepDims: false)
        let detClass = probs.argmax(axis: 1)
        
        return filterPrediction(boxes: detBoxes, probabilities: detProbs, classIndices: detClass, config: config)
    }
    
    private func filterPrediction(boxes: MfArray, probabilities: MfArray, classIndices: MfArray, config: SqueezeConfigWithAnchors) -> Any {
        var indicesInOrder: MfArray
        
        if (config.c.TOP_N_DETECTION > 0 && config.c.TOP_N_DETECTION < probabilities[0].count) {
            // let probabilitiesCopy = Matft.deepcopy(probabilities)
            let sortedIndices = Matft.sort(probabilities, axis: 0, order: .Descending)
            indicesInOrder = sortedIndices[0~<config.c.TOP_N_DETECTION]
        } else {
            indicesInOrder = probabilities[probabilities > config.c.PROB_THRESH]
            indicesInOrder = indicesInOrder[0]
        }
        
        var probabilitiesReshaped = probabilities.reshape([probabilities[0].count, 1])[indicesInOrder]
        probabilitiesReshaped = probabilitiesReshaped.reshape([indicesInOrder[0].count])
        let boxesSlice = boxes[indicesInOrder]
        var classIndicesReshaped = classIndices.reshape([classIndices[0].count, 1])[indicesInOrder]
        classIndicesReshaped = classIndicesReshaped.reshape([indicesInOrder[0].count])
        
        for i in 0...config.c.CLASSES {
            var indicesPerClass = classIndices[classIndices === i]
            indicesPerClass = indicesPerClass[0]
            
            if (indicesPerClass.isEmpty) {
                continue
            }
            
            let boxesSubset = MfArray([]) // to be computed
            
            
        }
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
    
    private func boundingBoxesFromDeltas(deltas: MfArray, config: SqueezeConfigWithAnchors) -> MfArray {
        let deltaX = deltas[0~<, 0]
        let deltaY = deltas[0~<, 1]
        let deltaW = deltas[0~<, 2]
        let deltaH = deltas[0~<, 3]
        
        let anchorX = config.anchorBox[0~<, 0]
        let anchorY = config.anchorBox[0~<, 1]
        let anchorW = config.anchorBox[0~<, 2]
        let anchorH = config.anchorBox[0~<, 3]
        
        let boxCenterX = Matft.add(anchorX, Matft.mul(deltaX, anchorW))
        let boxCenterY = Matft.add(anchorY, Matft.mul(deltaY, anchorH))
        
        let boxWidth = Matft.mul(anchorW, deltaW.safeExp(threshold: config.c.EXP_THRESH))
        let boxHeight = Matft.mul(anchorH, deltaH.safeExp(threshold: config.c.EXP_THRESH))
        
        let transformed = [boxCenterX, boxCenterY, boxWidth, boxHeight].bboxTransform()
        let xmins = transformed[0]
        let ymins = transformed[1]
        let xmaxs = transformed[2]
        let ymaxs = transformed[3]
        
        let transXmins = Matft.stats.minimum(
            Matft.stats.maximum(
                xmins,
                MfArray([0.0])
            ),
            MfArray([Float(config.c.IMAGE_WIDTH_PROCESSING - 1)])
        )
        let transYmins = Matft.stats.minimum(
            Matft.stats.maximum(
                ymins,
                MfArray([0.0])
            ),
            MfArray([Float(config.c.IMAGE_HEIGHT_PROCESSING - 1)])
        )
        let transXMaxs = Matft.stats.maximum(
            Matft.stats.minimum(
                xmaxs,
                MfArray([Float(config.c.IMAGE_WIDTH_PROCESSING - 1)])
            ),
            MfArray([0.0])
        )
        let transYMaxs = Matft.stats.maximum(
            Matft.stats.minimum(
                ymaxs,
                MfArray([Float(config.c.IMAGE_HEIGHT_PROCESSING - 1)])
            ),
            MfArray([0.0])
        )
        
        let s = Matft.vstack(
            [transXmins, transYmins, transXMaxs, transYMaxs].bboxTransformInverse()
        ).reshape([4, 14400])
        return s.transpose(axes: [1, 0])
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
    
    func safeExp(threshold: Float) -> MfArray {
        let slope = exp(threshold)
        let linBool = Matft.greater(self, threshold)
        let linRegion = Matft.deepcopy(linBool)
        let linOut = Matft.mul(Matft.sub(self, threshold - 1.0), slope)
        let selff = Matft.deepcopy(self)
        selff[selff > threshold] = MfArray([0.0])
        let expOut = Matft.math.exp(selff)
        let mull = Matft.mul(linRegion, linOut)
        let ones = MfArray(Array.init(repeating: 1, count: linRegion.count)).reshape(linRegion.shape).astype(linRegion.mftype)
        let subbed = Matft.sub(ones, linRegion)
        let exped = Matft.mul(subbed, expOut)
        return Matft.add(mull, exped)
    }
}

extension Array where Element : MfArray {
    func bboxTransform() -> [MfArray] {
        let cx = self[0]
        let cy = self[1]
        let w = self[2]
        let h = self[3]
        return [
            cx - w / 2,
            cy - h / 2,
            cx + w / 2,
            cy + h / 2
        ]
    }
    
    func bboxTransformInverse() -> [MfArray] {
        let xmin = self[0]
        let ymin = self[1]
        let xmax = self[2]
        let ymax = self[3]
        
        let width = xmax - xmin + 1.0
        let height = ymax - ymin + 1.0
        let result = [
            xmin + 0.5 * width,
            ymin + 0.5 * height,
            width,
            height
        ]
        return result
    }
}
