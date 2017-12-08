//
//  ViewController.swift
//  CoreMLDemo
//
//  Created by Kai-Ping Tseng on 2017/12/7.
//  Copyright © 2017年 Kai-Ping Tseng. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    @IBOutlet weak var previewView: UIView!
    
    @IBOutlet weak var predictionLabel: UILabel!
    
    var captureSession: AVCaptureSession!
    var cameraOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        cameraOutput = AVCapturePhotoOutput()
        
        let device = AVCaptureDevice.default(for: AVMediaType.video)
        
        if let input = try? AVCaptureDeviceInput(device: device!) {
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                
                if captureSession.canAddOutput(cameraOutput) {
                    captureSession.addOutput(cameraOutput)
                }
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                
                previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                previewLayer.frame = previewView.bounds
                previewView.layer.addSublayer(previewLayer)
                captureSession.startRunning()
            } else {
                print("could not add the input")
            }
        } else {
            print("could not find an input")
        }
        
        self.launchAI()
        
    }
    
    @objc func launchAI() {
        
        // capture an image from the video stream (camera)
        // we feed this image as the input of the ML model
        // we capture the result and process it back to the User Interface (label)
        
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                             kCVPixelBufferWidthKey as String: 160,
                             kCVPixelBufferHeightKey as String: 160]
        settings.previewPhotoFormat = previewFormat
        self.cameraOutput.capturePhoto(with: settings, delegate: self)
        
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("error occured: \(error.localizedDescription)")
        }
        
        if let imageData = photo.fileDataRepresentation(), let image = UIImage(data: imageData) {
            self.predict(image: image)
        }
    }
    
    func predict(image: UIImage) {
        // use the image as input to feed the model
        // run the model
        // get all the predictions from the completion handler method
        
        if let data = UIImagePNGRepresentation(image) {
            let fileName = URL.urlInDocumentsDirectory(with: "image.png")
        //let fileName = Bundle.main.url(forResource: "image", withExtension: "png")
            try? data.write(to: fileName)
            
            let model = try! VNCoreMLModel(for: VGG16().model)
            let request = VNCoreMLRequest(model: model, completionHandler: predictionCompleted)
            let handler = VNImageRequestHandler(url: fileName)
            try! handler.perform([request])
        }
        
        
    }
    
    func predictionCompleted(request: VNRequest, error: Error?) {
        self.predictionLabel.text = ""
        guard let results = request.results as? [VNClassificationObservation] else {
            fatalError("could not get any prediction output from ML model")
        }
        
        var bestPrediction = ""
        var confidence: VNConfidence = 0
        
        for classification in results {
            if classification.confidence > confidence {
                confidence = classification.confidence
                bestPrediction = classification.identifier
            }
        }
        
        self.predictionLabel.text = self.predictionLabel.text! + bestPrediction + "\n"
        
        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.launchAI), userInfo: nil, repeats: false)
    }
}

extension URL {
    static var documentsDirectory: URL {
        let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        return try! URL(fileURLWithPath: documentsDirectory)
    }
    
    static func urlInDocumentsDirectory(with filename: String) -> URL {
        return documentsDirectory.appendingPathComponent(filename)
    }
}
