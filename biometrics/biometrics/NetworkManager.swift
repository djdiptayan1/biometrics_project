//
//  NetworkManager.swift
//  biometrics
//
//  Created by Diptayan Jash on 18/08/25.
//

import SwiftUI
import Foundation
import Combine

struct BiometricAuthRequest {
    let image: UIImage
    let audioURL: URL
}

struct BiometricAuthResponse: Codable, Equatable {
    let success: Bool
    let message: String
    let name: String?
    let confidence: Double?
    let faceMatch: Bool?
    let voiceMatch: Bool?
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case encodingError
    case serverError(String)
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .encodingError:
            return "Failed to encode request"
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkUnavailable:
            return "Network unavailable"
        }
    }
}

class NetworkManager: ObservableObject {
    @Published var isLoading = false
    @Published var authResult: BiometricAuthResponse?
    @Published var errorMessage: String?
    
    // Configure your API endpoint here
    private let baseURL = "http://192.168.1.5:3000"
    private let authEndpoint = "/authenticate"
    
    private let session = URLSession.shared
    
    func authenticateBiometrics(image: UIImage, audioURL: URL) async throws -> BiometricAuthResponse {
        guard let url = URL(string: baseURL + authEndpoint) else {
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
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Create request body
        var body = Data()
        
        // Add image data
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"face.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add audio data
        do {
            let audioData = try Data(contentsOf: audioURL)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"voice.m4a\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n".data(using: .utf8)!)
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Failed to read audio file"
            }
            throw NetworkError.encodingError
        }
        
        // Add additional metadata if needed
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"timestamp\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(Date().timeIntervalSince1970)".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add device info
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"device_info\"\r\n\r\n".data(using: .utf8)!)
        body.append("iOS \(UIDevice.current.systemVersion)".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, response) = try await session.data(for: request)
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                guard 200...299 ~= httpResponse.statusCode else {
                    let errorMsg = "HTTP \(httpResponse.statusCode)"
                    DispatchQueue.main.async {
                        self.errorMessage = errorMsg
                    }
                    throw NetworkError.serverError(errorMsg)
                }
            }
            
            // Decode response
            guard !data.isEmpty else {
                throw NetworkError.noData
            }
            
            do {
                let authResponse = try JSONDecoder().decode(BiometricAuthResponse.self, from: data)
                DispatchQueue.main.async {
                    self.authResult = authResponse
                }
                return authResponse
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to parse response"
                }
                throw NetworkError.decodingError
            }
            
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                if error is NetworkError {
                    self.errorMessage = error.localizedDescription
                } else {
                    self.errorMessage = "Network request failed: \(error.localizedDescription)"
                }
            }
            throw error
        }
    }
    
    // Convenience method for SwiftUI integration
    func authenticateBiometricsAsync(image: UIImage, audioURL: URL) {
        Task {
            do {
                _ = try await authenticateBiometrics(image: image, audioURL: audioURL)
            } catch {
                // Error handling is done in the main method
                print("Authentication failed: \(error)")
            }
        }
    }
    
    // Reset state
    func resetState() {
        DispatchQueue.main.async {
            self.isLoading = false
            self.authResult = nil
            self.errorMessage = nil
        }
    }
}

// MARK: - API Configuration
extension NetworkManager {
    // Method to update API endpoint at runtime
    func updateAPIEndpoint(baseURL: String, endpoint: String = "/api/biometric-auth") {
        // Note: You might want to make baseURL and authEndpoint mutable for this
        // For now, this is a placeholder for configuration
        print("API Endpoint would be updated to: \(baseURL)\(endpoint)")
    }
    
    // Add authentication headers if needed
    private func addAuthHeaders(to request: inout URLRequest, token: String? = nil) {
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("iOS-Biometric-App/1.0", forHTTPHeaderField: "User-Agent")
    }
}

