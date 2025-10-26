//
//  SuccessView.swift
//  biometrics
//
//  Created by Diptayan Jash on 18/08/25.
//

import SwiftUI

struct SuccessView: View {
    @Environment(\.presentationMode) var presentationMode
    let authResult: BiometricVerificationResponse
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Success Icon
                Image(systemName: authResult.result.verified ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(authResult.result.verified ? .green : .red)
                
                Text(authResult.result.verified ? "Authentication Successful!" : "Authentication Failed")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // Display user's name
                if authResult.result.verified {
                    Text("Welcome, \(authResult.result.face.person.capitalized)!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                // Verification Details
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "faceid")
                            .foregroundColor(.blue)
                        Text("Face Recognition:")
                        Spacer()
                        Text(authResult.result.face.verified ? "✓ Verified" : "✗ Failed")
                            .foregroundColor(authResult.result.face.verified ? .green : .red)
                    }
                    
                    if authResult.result.face.verified {
                        HStack {
                            Spacer()
                            Text("\(authResult.result.face.person.capitalized) - \(String(format: "%.1f%%", authResult.result.face.confidence * 100))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.blue)
                        Text("Voice Recognition:")
                        Spacer()
                        Text(authResult.result.voice.verified ? "✓ Verified" : "✗ Failed")
                            .foregroundColor(authResult.result.voice.verified ? .green : .red)
                    }
                    
                    if authResult.result.voice.verified {
                        HStack {
                            Spacer()
                            Text("\(authResult.result.voice.person.capitalized) - \(String(format: "%.1f%%", authResult.result.voice.confidence * 100))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                        Text("Identity Match:")
                        Spacer()
                        Text(authResult.result.match.samePerson ? "✓ Same Person" : "✗ Mismatch")
                            .foregroundColor(authResult.result.match.samePerson ? .green : .orange)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)
                
                if authResult.result.verified {
                    Text("You have been successfully authenticated with both face and voice verification.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Authentication failed. Please try again.")
                        .font(.body)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(authResult.result.verified ? Color.blue : Color.gray)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding()
            .navigationTitle(authResult.result.verified ? "Success" : "Failed")
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    SuccessView(authResult: BiometricVerificationResponse(
        success: true,
        type: "biometric",
        result: VerificationResult(
            verified: true,
            face: FaceVerification(
                verified: true,
                person: "diptayan",
                confidence: 0.845,
                threshold: 0.65,
                similarities: ["diptayan": 0.845]
            ),
            voice: VoiceVerification(
                verified: true,
                person: "diptayan",
                confidence: 0.998,
                threshold: 0.41,
                similarities: ["diptayan": 0.998, "palash": 0.205]
            ),
            match: MatchResult(
                bothVerified: true,
                samePerson: true,
                facePerson: "diptayan",
                voicePerson: "diptayan"
            )
        )
    ))
}
