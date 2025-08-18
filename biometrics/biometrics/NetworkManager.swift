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
    let face_similarity: Double?
    let voice_similarity: Double?
    let result: Int?
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
    private var baseURL = "http://192.168.1.5:3000"
    private let authEndpoint = "/biometric/authenticate"
    
    private let session: URLSession
    
    init() {
        // Configure URL session with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
    }
    
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
        
        // Add image data as base64 form field with aggressive compression
        if let imageData = compressImage(image, targetSizeKB: 20) { // Target only 20KB for image
            let base64Image = imageData.base64EncodedString()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"\r\n\r\n".data(using: .utf8)!)
            body.append(base64Image.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add audio data as file (server expects it in request.files)
        do {
            let audioData = try Data(contentsOf: audioURL)
            // Compress audio data if it's too large
            let compressedAudioData = audioData.count > 100 * 1024 ? compressAudioData(audioData) : audioData
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"voice.m4a\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
            body.append(compressedAudioData)
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
        
        // Debug logging
        print("Making request to: \(url)")
        print("Request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Request body size: \(body.count) bytes")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
                print("Response Headers: \(httpResponse.allHeaderFields)")
                
                guard 200...299 ~= httpResponse.statusCode else {
                    let errorMsg = "HTTP \(httpResponse.statusCode)"
                    DispatchQueue.main.async {
                        self.errorMessage = errorMsg
                    }
                    throw NetworkError.serverError(errorMsg)
                }
            }
            
            // Debug: Print response data
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response Data: \(responseString)")
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
    
    // MARK: - Compression Utilities
    
    private func compressImage(_ image: UIImage, targetSizeKB: Int) -> Data? {
        let targetBytes = targetSizeKB * 1024
        
        // First, resize the image to a much smaller size for face recognition
        let maxDimension: CGFloat = 400  // Much smaller for face recognition
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        guard let resizedImage = resizeImage(image, to: newSize) else {
            return image.jpegData(compressionQuality: 0.1)
        }
        
        var compression: CGFloat = 0.3  // Start with lower quality
        guard var imageData = resizedImage.jpegData(compressionQuality: compression) else {
            return nil
        }
        
        // Aggressively reduce compression until we hit target
        while imageData.count > targetBytes && compression > 0.05 {
            compression -= 0.05
            if let newData = resizedImage.jpegData(compressionQuality: compression) {
                imageData = newData
            }
        }
        
        print("Image compressed from original to \(imageData.count) bytes (target: \(targetBytes))")
        return imageData
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    private func compressAudioData(_ audioData: Data) -> Data {
        // For basic compression, we'll just return the data as-is
        // In a real implementation, you might want to use AVAudioConverter
        // to re-encode the audio at a lower bitrate
        print("Audio data size: \(audioData.count) bytes (compression not implemented)")
        return audioData
    }
}

// MARK: - API Configuration
extension NetworkManager {
    // Method to update API endpoint at runtime
    func updateAPIEndpoint(baseURL: String, endpoint: String = "/biometric/authenticate") {
        self.baseURL = baseURL
        print("API Endpoint updated to: \(baseURL)\(endpoint)")
    }
    
    // Add authentication headers if needed
    private func addAuthHeaders(to request: inout URLRequest, token: String? = nil) {
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("iOS-Biometric-App/1.0", forHTTPHeaderField: "User-Agent")
    }
}

