//
//  SuccessView.swift
//  biometrics
//
//  Created by Diptayan Jash on 18/08/25.
//

import SwiftUI

struct SuccessView: View {
    @Environment(\.presentationMode) var presentationMode
    let authResult: BiometricAuthResponse
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Success Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.green)
                
                Text("Authentication Successful!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // Display user's name if available
                if let name = authResult.name {
                    Text("Welcome, \(name)!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "faceid")
                            .foregroundColor(.blue)
                        Text("Face Recognition:")
                        Spacer()
                        Text(authResult.faceMatch == true ? "✓ Verified" : "✗ Failed")
                            .foregroundColor(authResult.faceMatch == true ? .green : .red)
                    }
                    
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.blue)
                        Text("Voice Recognition:")
                        Spacer()
                        Text(authResult.voiceMatch == true ? "✓ Verified" : "✗ Failed")
                            .foregroundColor(authResult.voiceMatch == true ? .green : .red)
                    }
                    
                    if let confidence = authResult.confidence {
                        HStack {
                            Image(systemName: "gauge")
                                .foregroundColor(.blue)
                            Text("Confidence:")
                            Spacer()
                            Text("\(String(format: "%.1f", confidence * 100))%")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)
                
                Text("Welcome! You have been successfully authenticated.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding()
            .navigationTitle("Success")
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    SuccessView(authResult: BiometricAuthResponse(
        success: true,
        message: "Authentication successful",
        name: "Diptayan Jash",
        confidence: 0.95,
        faceMatch: true,
        voiceMatch: true,
        face_similarity: 0.92,
        voice_similarity: 0.90,
        result: 1
    ))
}
