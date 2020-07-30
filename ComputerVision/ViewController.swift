//
//  ViewController.swift
//  ComputerVision
//
//  Created by hjliu on 2020/7/28.
//  Copyright © 2020 劉紘任. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
  
  // 相機
  private lazy var captureSession = AVCaptureSession()
  private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
  private lazy var videoDataOutput = AVCaptureVideoDataOutput()
  
  var textLayers: [CALayer] = []
  var faceLayers: [CALayer] = []
  
  // 辨識等級
  private let recognitionLevel : VNRequestTextRecognitionLevel = .accurate
  
  // 辨識語言 英文
  private lazy var supportedRecognitionLanguages : [String] = {
    return (try? VNRecognizeTextRequest.supportedRecognitionLanguages(
      for: recognitionLevel,
      revision: VNRecognizeTextRequestRevision1)) ?? []
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupCamera()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
    self.captureSession.startRunning()
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    self.videoDataOutput.setSampleBufferDelegate(nil, queue: nil)
    self.captureSession.stopRunning()
  }
  
  // 相機設定
  private func setupCamera() {
    
    func setCameraInput() {
      guard let device = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
        mediaType: .video,
        position: .back).devices.first else {
          fatalError("No back camera device found.")
      }
      let cameraInput = try! AVCaptureDeviceInput(device: device)
      self.captureSession.addInput(cameraInput)
    }
    
    func showCameraFeed() {
      self.previewLayer.videoGravity = .resizeAspectFill
      self.view.layer.addSublayer(self.previewLayer)
      self.previewLayer.frame = self.view.frame
    }
    
    func setCameraOutput() {
      self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
      self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
      self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
      self.captureSession.addOutput(self.videoDataOutput)
      guard let connection = self.videoDataOutput.connection(with: AVMediaType.video), connection.isVideoOrientationSupported else { return }
      connection.videoOrientation = .portrait
    }
    
    setCameraInput()
    showCameraFeed()
    setCameraOutput()
    self.captureSession.startRunning()
  }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      debugPrint("unable to get image from sample buffer")
      return
    }
    
    self.imageHandler(pixelBuffer: pixelBuffer, textResult: { [weak self] textObservations in
      
      guard let self = self else { return }
      self.textHandler(textObservations: textObservations)
      
    }) { [weak self] faceObservations in
      
      guard let self = self else { return }
      self.faceHandler(faceObservations: faceObservations)
      
    }
  }
  
  private func imageHandler(pixelBuffer: CVPixelBuffer, textResult: @escaping (([VNRecognizedTextObservation])->()), faceResult: @escaping (([VNFaceObservation])->())) {
    
    // 臉部特徵
    let faceLandmarksRequest = VNDetectFaceLandmarksRequest { (request, error) in
      guard let results = request.results as? [VNFaceObservation] else {
        return
      }
    }
    
    // 文字
    let textRequest = VNRecognizeTextRequest { (request, error) in
      guard let results = request.results as? [VNRecognizedTextObservation] else {
        textResult([])
        return
      }
      textResult(results)
    }
    textRequest.recognitionLevel = self.recognitionLevel
    textRequest.recognitionLanguages = self.supportedRecognitionLanguages
    textRequest.usesLanguageCorrection = true
    
    // 臉
    let faceRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
      
      guard let results = request.results as? [VNFaceObservation] else {
        faceResult([])
        return
      }
      faceResult(results)
    })
    
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    try? handler.perform([textRequest, faceRequest])
  }
  
  private func textHandler(textObservations: [VNRecognizedTextObservation]) {
    
    DispatchQueue.main.async {
      
      self.textLayers.forEach({$0.removeFromSuperlayer()})
      self.textLayers = []
      
      let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.view.frame.size.height)
      let translate = CGAffineTransform.identity.scaledBy(x: self.view.frame.size.width, y: self.view.frame.size.height)
      
      for textObservation in textObservations {
        
        let finalRect = textObservation.boundingBox.applying(translate).applying(transform)
        let text = textObservation.topCandidates(1).first?.string ?? "" // 辨識文字
        let new = self.createTextLayer(in: finalRect, text: text)
        self.textLayers.append(new)
      }
    }
  }
  
  private func faceHandler(faceObservations: [VNFaceObservation]) {
    
    DispatchQueue.main.async {
      
      self.faceLayers.forEach({$0.removeFromSuperlayer()})
      self.faceLayers = []
      
      let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.view.frame.size.height)
      let translate = CGAffineTransform.identity.scaledBy(x: self.view.frame.size.width, y: self.view.frame.size.height)
      
      for faceObservation in faceObservations {
        
        let finalRect = faceObservation.boundingBox.applying(translate).applying(transform)
        let new = self.createFaceLayer(in: finalRect)
        self.faceLayers.append(new)
      }
    }
  }
  
  private func createFaceLayer(in rect: CGRect) -> CALayer {
    let layer = CAShapeLayer()
    layer.frame = rect
    layer.opacity = 0.75
    layer.borderColor = UIColor.red.cgColor
    layer.borderWidth = 2.0
    previewLayer.insertSublayer(layer, at: 1)
    return layer
  }
  
  private func createTextLayer(in rect: CGRect, text: String) -> CALayer {
    let layer = CATextLayer()
    layer.string = text
    layer.foregroundColor = UIColor.blue.cgColor
    //    layer.backgroundColor = UIColor.blue.cgColor
    layer.fontSize = rect.height
    layer.frame = rect
    layer.opacity = 0.75
    //    layer.borderColor = UIColor.green.cgColor
    //    layer.borderWidth = 2.0
    previewLayer.insertSublayer(layer, at: 1)
    return layer
  }
}



//class ViewController: UIViewController {
//
//  // 相機
//  private lazy var captureSession = AVCaptureSession()
//  private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
//  private lazy var videoDataOutput = AVCaptureVideoDataOutput()
//
//  private var maskLayer = CAShapeLayer()
//
//  // 文字辨識
//  var textRecognitionRequest = VNRecognizeTextRequest(completionHandler: nil)
//  private let textRecognitionWorkQueue = DispatchQueue(label: "MyVisionScannerQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
//
//  private var isProcess = false
//
//  lazy var digitsLabel : UILabel = {
//    let b = UILabel(frame: .zero)
//    view.addSubview(b)
//    b.translatesAutoresizingMaskIntoConstraints = false
//    b.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
//    b.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
//    b.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20).isActive = true
//    b.heightAnchor.constraint(equalToConstant: 30).isActive = true
//    return b
//  }()
//
//  override func viewDidLoad() {
//    super.viewDidLoad()
//    setCaptureVideo()
//    setupVision()
//  }
//
//  override func viewDidAppear(_ animated: Bool) {
//    self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
//    self.captureSession.startRunning()
//  }
//
//  override func viewDidDisappear(_ animated: Bool) {
//    self.videoDataOutput.setSampleBufferDelegate(nil, queue: nil)
//    self.captureSession.stopRunning()
//  }
//
//  // 相機設定
//  private func setCaptureVideo() {
//
//    func setCameraInput() {
//      guard let device = AVCaptureDevice.DiscoverySession(
//        deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
//        mediaType: .video,
//        position: .back).devices.first else {
//          fatalError("No back camera device found.")
//      }
//      let cameraInput = try! AVCaptureDeviceInput(device: device)
//      self.captureSession.addInput(cameraInput)
//    }
//
//    func showCameraFeed() {
//      self.previewLayer.videoGravity = .resizeAspectFill
//      self.view.layer.addSublayer(self.previewLayer)
//      self.previewLayer.frame = self.view.frame
//    }
//
//    func setCameraOutput() {
//      self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
//      self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
//      self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
//      self.captureSession.addOutput(self.videoDataOutput)
//      guard let connection = self.videoDataOutput.connection(with: AVMediaType.video), connection.isVideoOrientationSupported else { return }
//      connection.videoOrientation = .portrait
//    }
//
//    setCameraInput()
//    showCameraFeed()
//    setCameraOutput()
//    self.captureSession.startRunning()
//  }
//}
//
//extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
//
//  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//
//    guard let image = CMSampleBufferGetImageBuffer(sampleBuffer) else {
//      debugPrint("unable to get image from sample buffer")
//      return
//    }
//    self.detectRectangle(in: image)
//  }
//
//  private func detectRectangle(in image: CVPixelBuffer) {
//
//    let request = VNDetectRectanglesRequest(completionHandler: { (request: VNRequest, error: Error?) in
//      DispatchQueue.main.async {
//
//        guard let results = request.results as? [VNRectangleObservation] else { return }
//        self.removeMask()
//        guard let rect = results.first else{return}
//        self.drawBoundingBox(rect: rect)
//
//        if self.isProcess == false {
//          self.isProcess = true
//
//          // 校正圖
//          if let newImage = self.doPerspectiveCorrection(rect, from: image) {
//            self.recognizeTextInImage(newImage) // 辨識文字
//          }
//        }
//      }
//    })
//    request.minimumAspectRatio = VNAspectRatio(1.3)
//    request.maximumAspectRatio = VNAspectRatio(1.6)
//    request.minimumSize = Float(0.5)
//    request.maximumObservations = 1
//    let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, options: [:])
//    try? imageRequestHandler.perform([request])
//  }
//
//  private func removeMask() {
//    maskLayer.removeFromSuperlayer()
//  }
//
//  private func drawBoundingBox(rect : VNRectangleObservation) {
//    let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.previewLayer.frame.height)
//    let scale = CGAffineTransform.identity.scaledBy(x: self.previewLayer.frame.width, y: self.previewLayer.frame.height)
//    let bounds = rect.boundingBox.applying(scale).applying(transform)
//    createLayer(in: bounds)
//  }
//
//  private func createLayer(in rect: CGRect) {
//    maskLayer = CAShapeLayer()
//    maskLayer.frame = rect
//    maskLayer.cornerRadius = 10
//    maskLayer.opacity = 0.75
//    maskLayer.borderColor = UIColor.red.cgColor
//    maskLayer.borderWidth = 5.0
//    previewLayer.insertSublayer(maskLayer, at: 1)
//  }
//
//  func doPerspectiveCorrection(_ observation: VNRectangleObservation, from buffer: CVImageBuffer) -> CGImage? {
//
//    var ciImage = CIImage(cvImageBuffer: buffer)
//    let topLeft = observation.topLeft.scaled(to: ciImage.extent.size)
//    let topRight = observation.topRight.scaled(to: ciImage.extent.size)
//    let bottomLeft = observation.bottomLeft.scaled(to: ciImage.extent.size)
//    let bottomRight = observation.bottomRight.scaled(to: ciImage.extent.size)
//    ciImage = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
//      "inputTopLeft": CIVector(cgPoint: topLeft),
//      "inputTopRight": CIVector(cgPoint: topRight),
//      "inputBottomLeft": CIVector(cgPoint: bottomLeft),
//      "inputBottomRight": CIVector(cgPoint: bottomRight),
//    ])
//    let context = CIContext()
//    let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
//    return cgImage
//  }
//}
//
//extension ViewController {
//
//  private func setupVision() {
//
//    textRecognitionRequest = VNRecognizeTextRequest { (request, error) in
//
//      guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
//
//      var detectedText = "無資訊"
//      var detectedTexts: [String] = []
//
//      for observation in observations {
//
//        observation.topCandidates(1).forEach({ detectedTexts.append($0.string) })
//      }
//
//      detectedTexts.forEach({ text in
//
//        print("\(text)--->")
//
//        let newStr = text.components(separatedBy: " ").joined()
//        if newStr.isNumber && newStr.count == 16 {
//          let formattedUnionPayCardNumber = newStr.replacingOccurrences(of: "(\\d{4})(\\d{4})(\\d{4})(\\d{4})(\\d+)", with: "$1 $2 $3 $4 $5", options: .regularExpression, range: nil)
//          detectedText = formattedUnionPayCardNumber
//        }
//      })
//
//      DispatchQueue.main.async{
//        self.digitsLabel.text = detectedText
//      }
//
//      self.isProcess = false
//    }
//    textRecognitionRequest.recognitionLevel = .accurate
//  }
//
//  // 辨識文字
//  private func recognizeTextInImage(_ cgImage: CGImage) {
//
//    textRecognitionWorkQueue.async {
//      let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
//      do {
//        try requestHandler.perform([self.textRecognitionRequest])
//      } catch {
//        print(error)
//      }
//    }
//  }
//
//}
