//
//  CameraManager.swift
//  biometrics
//
//  Created by Diptayan Jash on 17/08/25.
//

import SwiftUI
import AVFoundation
import UIKit
import Combine

class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer!
    
    private var photoCompletion: ((UIImage?) -> Void)?
    
    override init() {
        super.init()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.isAuthorized = true
                self.setupCamera()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    if granted {
                        self.setupCamera()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        @unknown default:
            break
        }
    }
    
    func setupCamera() {
        do {
            session.beginConfiguration()
            
            // Use front camera
            guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                print("Front camera not available")
                return
            }
            
            let input = try AVCaptureDeviceInput(device: frontCamera)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            
            DispatchQueue.global(qos: .background).async {
                self.session.startRunning()
            }
            
        } catch {
            print("Error setting up camera: \(error)")
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            photoCompletion?(nil)
            return
        }
        
        photoCompletion?(image)
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        cameraManager.preview = AVCaptureVideoPreviewLayer(session: cameraManager.session)
        cameraManager.preview.frame = view.frame
        cameraManager.preview.videoGravity = .resizeAspectFill
        
        view.layer.addSublayer(cameraManager.preview)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let preview = cameraManager.preview {
            preview.frame = uiView.frame
        }
    }
}
