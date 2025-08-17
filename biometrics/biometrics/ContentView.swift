//
//  ContentView.swift
//  biometrics
//
//  Created by Diptayan Jash on 17/08/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var showingBiometricCapture = false
    @State private var showingSuccessView = false
    @State private var authResult: BiometricAuthResponse?
    @State private var authMessage: String = ""
    @State private var showingAuthMessage = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Biometric Authentication")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Image(systemName: "faceid")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Secure access with face and voice recognition")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    showingBiometricCapture = true
                }) {
                    Text("Start Authentication")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                if !authMessage.isEmpty {
                    Text(authMessage)
                        .font(.body)
                        .foregroundColor(authResult?.success == true ? .green : .red)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
            }
            .navigationTitle("Biometrics")
            .sheet(isPresented: $showingBiometricCapture) {
                BiometricCaptureView { result in
                    handleAuthenticationResult(result)
                }
            }
            .fullScreenCover(isPresented: $showingSuccessView) {
                if let result = authResult {
                    SuccessView(authResult: result)
                }
            }
        }
    }
    
    private func handleAuthenticationResult(_ result: BiometricAuthResponse) {
        authResult = result
        
        if result.success {
            // Both face and voice matched
            let welcomeMessage = if let name = result.name {
                "✅ Authentication Successful!\nWelcome back, \(name)!"
            } else {
                "✅ Authentication Successful!\nWelcome back!"
            }
            authMessage = welcomeMessage
            showingSuccessView = true
        } else {
            // Handle different failure scenarios
            let faceMatch = result.faceMatch ?? false
            let voiceMatch = result.voiceMatch ?? false
            
            if faceMatch && !voiceMatch {
                authMessage = "❌ Authentication Failed\n\n✓ Face verified\n✗ Voice did not match\n\nPlease try again with clearer voice recording."
            } else if !faceMatch && voiceMatch {
                authMessage = "❌ Authentication Failed\n\n✗ Face did not match\n✓ Voice verified\n\nPlease ensure proper lighting and face positioning."
            } else if !faceMatch && !voiceMatch {
                authMessage = "❌ Authentication Failed\n\n✗ Face did not match\n✗ Voice did not match\n\nPlease try again with both face and voice."
            } else {
                authMessage = "❌ Authentication Failed\n\n\(result.message)"
            }
            showingSuccessView = false
        }
        }
    }

#Preview {
    ContentView()
}
