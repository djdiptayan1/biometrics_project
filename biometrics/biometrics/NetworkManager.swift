//
//  NetworkManager.swift
//  biometrics
//
//  Created by Diptayan Jash on 18/08/25.
//

import SwiftUI
import Foundation
import Combine

// MARK: - API Response Models

struct BiometricVerificationResponse: Codable {
    let success: Bool
    let type: String
    let result: VerificationResult
}

// MARK: - Server (raw) Response Models
// These match the actual server payload observed in the logs
private struct RawClassResult: Codable {
    let className: String
    let probability: Double

    enum CodingKeys: String, CodingKey {
        case className = "className"
        case probability = "probability"
    }
}

private struct RawAudioOrImage: Codable {
    let results: [RawClassResult]
}

private struct RawResultBlock: Codable {
    let authenticated: Bool?
    let name: String?
}

private struct RawServerResponse: Codable {
    let audio: RawAudioOrImage?
    let image: RawAudioOrImage?
    let result: RawResultBlock?
}

struct VerificationResult: Codable {
    let verified: Bool
    let face: FaceVerification
    let voice: VoiceVerification
    let match: MatchResult
}

struct FaceVerification: Codable {
    let verified: Bool
    let person: String
    let confidence: Double
    let threshold: Double
    let similarities: [String: Double]
}

struct VoiceVerification: Codable {
    let verified: Bool
    let person: String
    let confidence: Double
    let threshold: Double
    let similarities: [String: Double]
}

struct MatchResult: Codable {
    let bothVerified: Bool
    let samePerson: Bool
    let facePerson: String
    let voicePerson: String
    
    enum CodingKeys: String, CodingKey {
        case bothVerified = "both_verified"
        case samePerson = "same_person"
        case facePerson = "face_person"
        case voicePerson = "voice_person"
    }
}

// MARK: - Network Error

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case encodingError
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received from server"
        case .decodingError:
            return "Failed to decode server response"
        case .encodingError:
            return "Failed to encode request data"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

// MARK: - Network Manager

class NetworkManager: ObservableObject {
    @Published var isLoading = false
    @Published var authResult: BiometricVerificationResponse?
    @Published var errorMessage: String?
    
    // API Configuration
    private let baseURL = "http://192.168.1.2:3000"
    private let verifyEndpoint = "/verify"
    
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Main Authentication Method
    
    func authenticateBiometrics(image: UIImage, audioURL: URL) async throws -> BiometricVerificationResponse {
        guard let url = URL(string: baseURL + verifyEndpoint) else {
            throw NetworkError.invalidURL
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add image file
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add audio file
        do {
            let audioData = try Data(contentsOf: audioURL)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n".data(using: .utf8)!)
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Failed to read audio file"
            }
            throw NetworkError.encodingError
        }
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        print("📡 Sending request to: \(url)")
        print("📦 Request body size: \(body.count) bytes")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ HTTP Status: \(httpResponse.statusCode)")
                
                guard 200...299 ~= httpResponse.statusCode else {
                    let errorMsg = "HTTP \(httpResponse.statusCode)"
                    DispatchQueue.main.async {
                        self.errorMessage = errorMsg
                    }
                    throw NetworkError.serverError(errorMsg)
                }
            }
            
            // Debug response
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Response: \(responseString)")
            }
            
            guard !data.isEmpty else {
                throw NetworkError.noData
            }
            
            // Decode response (server uses a different shape than our in-app model)
            do {
                let decoder = JSONDecoder()
                let raw = try decoder.decode(RawServerResponse.self, from: data)

                // Map raw results into our app model (use simple heuristics/thresholds)
                let faceTop = raw.image?.results.sorted(by: { $0.probability > $1.probability }).first
                let voiceTop = raw.audio?.results.sorted(by: { $0.probability > $1.probability }).first

                // Thresholds (tweakable)
                let faceThreshold = 0.5
                let voiceThreshold = 0.4

                let faceVerified = (faceTop?.probability ?? 0.0) >= faceThreshold
                let voiceVerified = (voiceTop?.probability ?? 0.0) >= voiceThreshold

                let facePerson = faceTop?.className ?? "unknown"
                let voicePerson = voiceTop?.className ?? "unknown"

                let faceConfidence = faceTop?.probability ?? 0.0
                let voiceConfidence = voiceTop?.probability ?? 0.0

                let samePerson = facePerson == voicePerson && faceVerified && voiceVerified

                // Build VerificationResult used by UI
                let faceVerification = FaceVerification(
                    verified: faceVerified,
                    person: facePerson,
                    confidence: faceConfidence,
                    threshold: faceThreshold,
                    similarities: raw.image?.results.reduce(into: [String: Double](), { res, item in res[item.className] = item.probability }) ?? [:]
                )

                let voiceVerification = VoiceVerification(
                    verified: voiceVerified,
                    person: voicePerson,
                    confidence: voiceConfidence,
                    threshold: voiceThreshold,
                    similarities: raw.audio?.results.reduce(into: [String: Double](), { res, item in res[item.className] = item.probability }) ?? [:]
                )

                let matchResult = MatchResult(
                    bothVerified: faceVerified && voiceVerified,
                    samePerson: samePerson,
                    facePerson: facePerson,
                    voicePerson: voicePerson
                )

                let verificationResult = VerificationResult(
                    verified: (raw.result?.authenticated == true) || (faceVerified && voiceVerified && samePerson),
                    face: faceVerification,
                    voice: voiceVerification,
                    match: matchResult
                )

                let mapped = BiometricVerificationResponse(
                    success: raw.result?.authenticated ?? (faceVerified && voiceVerified && samePerson),
                    type: "biometric",
                    result: verificationResult
                )

                DispatchQueue.main.async {
                    self.authResult = mapped
                }

                return mapped
            } catch {
                print("❌ Decoding error: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to parse server response"
                }
                throw NetworkError.decodingError
            }
            
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    func resetState() {
        DispatchQueue.main.async {
            self.isLoading = false
            self.authResult = nil
            self.errorMessage = nil
        }
    }
}

