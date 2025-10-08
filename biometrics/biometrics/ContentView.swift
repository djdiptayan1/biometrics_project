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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 12) {
                    Text("Biometric Authentication")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Image(systemName: "faceid")
                        .font(.system(size: 80, weight: .regular))
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                    
                    Text("Secure access with face and voice recognition")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Start button
                Button(action: {
                    showingBiometricCapture = true
                }) {
                    Text("Start Authentication")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                
                // Auth message card
                if !authMessage.isEmpty {
                    VStack {
                        Text(authMessage)
                            .font(.body)
                            .foregroundColor(authResult?.success == true ? .green : .red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut, value: authMessage)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .sheet(isPresented: $showingBiometricCapture) {
                BiometricCaptureView { result in
                    handleAuthenticationResult(result)
                }
            }
            .fullScreenCover(isPresented: $showingSuccessView) {
                if let result = authResult {
                    SuccessView(authResult: result)
                        .transition(.opacity)
                }
            }
        }
    }
    
    private func handleAuthenticationResult(_ result: BiometricAuthResponse) {
        authResult = result
        
        if result.success {
            let welcomeMessage = if let name = result.name {
                "✅ Authentication Successful!\nWelcome back, \(name)!"
            } else {
                "✅ Authentication Successful!\nWelcome back!"
            }
            authMessage = welcomeMessage
            showingSuccessView = true
        } else {
            let faceMatch = result.faceMatch ?? false
            let voiceMatch = result.voiceMatch ?? false
            
            if faceMatch && !voiceMatch {
                authMessage = "❌ Authentication Failed\n\n✓ Face verified\n✗ Voice did not match\n\nTry again with clearer voice recording."
            } else if !faceMatch && voiceMatch {
                authMessage = "❌ Authentication Failed\n\n✗ Face did not match\n✓ Voice verified\n\nEnsure proper lighting and face positioning."
            } else if !faceMatch && !voiceMatch {
                authMessage = "❌ Authentication Failed\n\n✗ Face did not match\n✗ Voice did not match\n\nPlease try again."
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
