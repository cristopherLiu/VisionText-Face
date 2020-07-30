//
//  TextExtractorVC.swift
//  ComputerVision
//
//  Created by hjliu on 2020/7/28.
//  Copyright © 2020 劉紘任. All rights reserved.
//

import UIKit
import Vision

class TextExtractorVC: UIViewController {
  
//  let queue = OperationQueue()
  var textRecognitionRequest = VNRecognizeTextRequest(completionHandler: nil)
  private let textRecognitionWorkQueue = DispatchQueue(label: "MyVisionScannerQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
  
  var scannedImage : UIImage?
  
  private var maskLayer = [CAShapeLayer]()
  
  lazy var imageView : UIImageView = {
    
    let b = UIImageView()
    b.contentMode = .scaleAspectFit
    
    view.addSubview(b)
    
    b.translatesAutoresizingMaskIntoConstraints = false
    b.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
    b.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    b.topAnchor.constraint(equalTo: view.topAnchor, constant: 30).isActive = true
    b.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    
    return b
    
  }()
  
  lazy var button : UIButton = {
    
    let b = UIButton(type: .system)
    b.setTitle("Extract Digits", for: .normal)
    view.addSubview(b)
    
    b.translatesAutoresizingMaskIntoConstraints = false
    b.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
    b.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    b.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    b.heightAnchor.constraint(equalToConstant: 50).isActive = true
    
    return b
    
  }()
  
  lazy var digitsLabel : UILabel = {
    
    let b = UILabel(frame: .zero)
    
    view.addSubview(b)
    
    b.translatesAutoresizingMaskIntoConstraints = false
    b.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
    b.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    b.bottomAnchor.constraint(equalTo: self.button.topAnchor, constant: -20).isActive = true
    b.heightAnchor.constraint(equalToConstant: 30).isActive = true
    
    return b
    
  }()
  
  @objc func doExtraction(sender: UIButton){
    if let scannedImage = scannedImage {
      processImage(scannedImage)
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupVision()
    self.view.backgroundColor = .black
    
    imageView.image = scannedImage
    button.addTarget(self, action: #selector(doExtraction(sender:)), for: .touchUpInside)
  }
  
  private func setupVision() {
    
    textRecognitionRequest = VNRecognizeTextRequest { (request, error) in
      guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
      
      var detectedText = "無資訊"
      var detectedTexts: [String] = []
      
      for observation in observations {
        observation.topCandidates(1).forEach({ detectedTexts.append($0.string) })
      }

      detectedTexts.forEach({ text in
        
        print("\(text)--->")
        
        let newStr = text.components(separatedBy: " ").joined()
        if newStr.isNumber && newStr.count == 16 {
          let formattedUnionPayCardNumber = newStr.replacingOccurrences(of: "(\\d{4})(\\d{4})(\\d{4})(\\d{4})(\\d+)", with: "$1 $2 $3 $4 $5", options: .regularExpression, range: nil)
          detectedText = formattedUnionPayCardNumber
        }
      })
      
      DispatchQueue.main.async{
        self.digitsLabel.text = detectedText
      }
    }
    textRecognitionRequest.recognitionLevel = .accurate
  }
  
  private func processImage(_ image: UIImage) {
    recognizeTextInImage(image)
  }
  
  private func recognizeTextInImage(_ image: UIImage) {
    guard let cgImage = image.cgImage else { return }
    
    textRecognitionWorkQueue.async {
      let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      do {
        try requestHandler.perform([self.textRecognitionRequest])
      } catch {
        print(error)
      }
    }
  }
}
