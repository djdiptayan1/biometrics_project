from flask import request, jsonify
from services.biometric_auth_service import BiometricAuthService

biometric_service = BiometricAuthService()


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

        # Replace TODO: Implement actual biometric authentication logic
        result = biometric_service.verify_user(image_file.read(), audio_file.read())

        if not result["success"]:
            return jsonify({
                "success": False,
                "error": result.get("error", "Authentication failed"),
                "authenticated": bool(result.get("authenticated", False)),  # Ensure boolean is JSON serializable
            }), 400

        return jsonify({
            "success": True,
            "authenticated": bool(result["authenticated"]),  # Ensure boolean is JSON serializable
            "face_similarity": float(result["face_similarity"]),
            "voice_similarity": float(result["voice_similarity"]),
            "result": result["result"]
        }), 200
