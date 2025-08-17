from flask import request, jsonify
import random
from models.auth_models import BiometricAuthResponse, AuthErrorResponse, FileValidation


class AuthController:
    @staticmethod
    def authenticate():
        """
        Handle biometric authentication with image and audio files
        Returns a BiometricAuthResponse or AuthErrorResponse as JSON
        """
        # Check if required files are present
        if "image" not in request.files or "audio" not in request.files:
            error_response = AuthErrorResponse(message="Missing image or audio file")
            return jsonify(error_response.dict()), 400

        image_file = request.files["image"]
        audio_file = request.files["audio"]

        # Validate file types using Pydantic validation helper
        if not FileValidation.is_valid_image(image_file.filename):
            error_response = AuthErrorResponse(message="Invalid image file format")
            return jsonify(error_response.dict()), 400

        if not FileValidation.is_valid_audio(audio_file.filename):
            error_response = AuthErrorResponse(message="Invalid audio file format")
            return jsonify(error_response.dict()), 400

        # TODO: Implement actual biometric authentication logic
        # For now, simulating authentication with random values

        success = True
        message = "Authentication successful"
        confidence = 0.95
        face_match = True
        voice_match = True

        if success:
            auth_response = BiometricAuthResponse(
                success=success,
                message=message,
                name="Diptayan Jash",  # TODO: Get from actual authentication
                confidence=confidence,
                faceMatch=face_match,
                voiceMatch=voice_match,
            )
        else:
            auth_response = BiometricAuthResponse(
                success=success,
                message=message,
                name=None,
                confidence=confidence,
                faceMatch=face_match,
                voiceMatch=voice_match,
            )

        return jsonify(auth_response.dict()), 200
