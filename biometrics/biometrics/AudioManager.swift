//
//  AudioManager.swift
//  biometrics
//
//  Created by Diptayan Jash on 17/08/25.
//

import SwiftUI
import AVFoundation
import Combine

class AudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var hasRecording = false
    @Published var recordingTime: Double = 0.0
    @Published var isAuthorized = false
    @Published var isPlaying = false
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var recordingSession: AVAudioSession!
    
    private let maxRecordingTime: Double = 5.0
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    func checkPermissions() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
        case .denied:
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                }
            }
        @unknown default:
            break
        }
    }
    
    private func setupAudioSession() {
        recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try recordingSession.setActive(true)
        } catch {
            print("Failed to set up recording session: \(error)")
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        let audioFilename = getDocumentsDirectory().appendingPathComponent("voice_recording.m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.recordingTime = 0.0
                self.hasRecording = false
            }
            
            startTimer()
            
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.hasRecording = true
        }
        
        stopTimer()
    }
    
    func playRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("voice_recording.m4a")
        
        // Ensure audio plays through speaker
        do {
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
        } catch {
            print("Could not override audio output to speaker: \(error)")
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFilename)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            
            DispatchQueue.main.async {
                self.isPlaying = true
            }
        } catch {
            print("Could not play recording: \(error)")
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    func deleteRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("voice_recording.m4a")
        
        do {
            try FileManager.default.removeItem(at: audioFilename)
        } catch {
            print("Could not delete recording: \(error)")
        }
        
        DispatchQueue.main.async {
            self.hasRecording = false
            self.recordingTime = 0.0
            self.isPlaying = false
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.recordingTime += 0.1
                
                if self.recordingTime >= self.maxRecordingTime {
                    self.stopRecording()
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

extension AudioManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            DispatchQueue.main.async {
                self.hasRecording = true
            }
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Recording error: \(error?.localizedDescription ?? "Unknown error")")
        DispatchQueue.main.async {
            self.isRecording = false
        }
        stopTimer()
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Playback error: \(error?.localizedDescription ?? "Unknown error")")
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}
