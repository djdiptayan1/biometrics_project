//
//  BiometricCaptureView.swift
//  biometrics
//
//  Created by Diptayan Jash on 17/08/25.
//

import SwiftUI
import AVFoundation

struct BiometricCaptureView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var networkManager = NetworkManager()
    @State private var capturedImage: UIImage?
    @State private var showingSuccessAlert = false
    @State private var showingAuthResult = false
    
    let onAuthenticationComplete: (BiometricVerificationResponse) -> Void
    
    init(onAuthenticationComplete: @escaping (BiometricVerificationResponse) -> Void = { _ in }) {
        self.onAuthenticationComplete = onAuthenticationComplete
    }
    
    // Computed property for button color
    private var authenticateButtonColor: Color {
        if networkManager.isLoading {
            return .orange
        } else if capturedImage != nil && audioManager.hasRecording {
            return .blue
        } else {
            return .gray
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Camera Section
                VStack {
                    Text("Face Capture")
                        .font(.headline)
                        .padding(.top)
                    
                    ZStack {
                        if let image = capturedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 300)
                                .clipped()
                                .cornerRadius(15)
                        } else {
                            CameraPreview(cameraManager: cameraManager)
                                .frame(height: 300)
                                .cornerRadius(15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                        }
                        
                        VStack {
                            Spacer()
                            HStack {
                                if capturedImage == nil {
                                    Button(action: {
                                        cameraManager.capturePhoto { image in
                                            capturedImage = image
                                        }
                                    }) {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 70, height: 70)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.gray, lineWidth: 2)
                                                    .frame(width: 60, height: 60)
                                            )
                                    }
                                } else {
                                    Button(action: {
                                        capturedImage = nil
                                    }) {
                                        Text("Retake")
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(Color.blue)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                    .padding(.vertical)
                
                // Audio Recording Section
                VStack {
                    Text("Voice Recording")
                        .font(.headline)
                    
                    VStack(spacing: 20) {
                        // Recording indicator
                        ZStack {
                            Circle()
                                .fill(audioManager.isRecording ? Color.red.opacity(0.3) : Color.gray.opacity(0.3))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: audioManager.isRecording ? "mic.fill" : "mic")
                                .font(.system(size: 40))
                                .foregroundColor(audioManager.isRecording ? .red : .gray)
                        }
                        
                        // Timer display
                        Text(String(format: "%.1f / 5.0 seconds", audioManager.recordingTime))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Recording controls
                        HStack(spacing: 30) {
                            if !audioManager.isRecording && !audioManager.hasRecording {
                                Button(action: {
                                    audioManager.startRecording()
                                }) {
                                    Text("Start Recording")
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.red)
                                        .cornerRadius(20)
                                }
                            } else if audioManager.isRecording {
                                Button(action: {
                                    audioManager.stopRecording()
                                }) {
                                    Text("Stop")
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.gray)
                                        .cornerRadius(20)
                                }
                            } else {
                                HStack(spacing: 20) {
                                    Button(action: {
                                        if audioManager.isPlaying {
                                            audioManager.stopPlayback()
                                        } else {
                                            audioManager.playRecording()
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: audioManager.isPlaying ? "stop.fill" : "play.fill")
                                            Text(audioManager.isPlaying ? "Stop" : "Play")
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .cornerRadius(15)
                                    }
                                    
                                    Button(action: {
                                        if audioManager.isPlaying {
                                            audioManager.stopPlayback()
                                        }
                                        audioManager.deleteRecording()
                                    }) {
                                        Text("Re-record")
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 15)
                                            .padding(.vertical, 8)
                                            .background(Color.red.opacity(0.1))
                                            .cornerRadius(15)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Unlock Button
                Button(action: {
                    if let image = capturedImage, audioManager.hasRecording {
                        let audioURL = getDocumentsDirectory().appendingPathComponent("voice_recording.wav")
                        Task {
                            do {
                                _ = try await networkManager.authenticateBiometrics(image: image, audioURL: audioURL)
                            } catch {
                                print("Authentication error: \(error)")
                            }
                        }
                    }
                }) {
                    HStack {
                        if networkManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Authenticating...")
                        } else {
                            Text("Authenticate")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(authenticateButtonColor)
                    .cornerRadius(10)
                }
                .disabled(capturedImage == nil || !audioManager.hasRecording || networkManager.isLoading)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Biometric Capture")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                cameraManager.checkPermissions()
                audioManager.checkPermissions()
            }
            .onChange(of: networkManager.authResult != nil) { hasResult in
                if hasResult {
                    showingAuthResult = true
                }
            }
            .onChange(of: networkManager.errorMessage) { error in
                if let _ = error {
                    showingAuthResult = true
                }
            }
            .alert("Authentication Result", isPresented: $showingAuthResult) {
                Button("OK") {
                    if let result = networkManager.authResult {
                        onAuthenticationComplete(result)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } message: {
                if let result = networkManager.authResult {
                    if result.success && result.result.verified {
                        Text("✅ Authentication Successful!\n\nIdentity: \(result.result.face.person.capitalized)\nFace: \(String(format: "%.1f%%", result.result.face.confidence * 100))\nVoice: \(String(format: "%.1f%%", result.result.voice.confidence * 100))")
                    } else {
                        Text("❌ Authentication Failed\n\nPlease try again.")
                    }
                } else if let error = networkManager.errorMessage {
                    Text("❌ Error: \(error)")
                } else {
                    Text("Unknown error occurred")
                }
            }
        }
    }
    
    // Helper function to get documents directory
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

#Preview {
    BiometricCaptureView { result in
        print("Authentication result: \(result)")
    }
}
