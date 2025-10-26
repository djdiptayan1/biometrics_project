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
    @State private var authResult: BiometricVerificationResponse?
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
    
    private func handleAuthenticationResult(_ result: BiometricVerificationResponse) {
        authResult = result
        
        if result.success && result.result.verified {
            let name = result.result.face.person.capitalized
            authMessage = "✅ Authentication Successful!\nWelcome back, \(name)!"
            showingSuccessView = true
        } else {
            let faceVerified = result.result.face.verified
            let voiceVerified = result.result.voice.verified
            let samePerson = result.result.match.samePerson
            
            if faceVerified && voiceVerified && !samePerson {
                authMessage = "❌ Authentication Failed\n\n✓ Face verified: \(result.result.face.person)\n✓ Voice verified: \(result.result.voice.person)\n✗ Identity mismatch\n\nFace and voice belong to different people."
            } else if faceVerified && !voiceVerified {
                authMessage = "❌ Authentication Failed\n\n✓ Face verified\n✗ Voice did not match\n\nTry again with clearer voice recording."
            } else if !faceVerified && voiceVerified {
                authMessage = "❌ Authentication Failed\n\n✗ Face did not match\n✓ Voice verified\n\nEnsure proper lighting and face positioning."
            } else {
                authMessage = "❌ Authentication Failed\n\n✗ Face did not match\n✗ Voice did not match\n\nPlease try again."
            }
            showingSuccessView = false
        }
    }
}
#Preview {
    ContentView()
}
