from flask import Blueprint, jsonify, request
from controllers.auth_controller import AuthController
from services.face_auth_service import FaceAuthService
from services.biometric_auth_service import BiometricAuthService
from werkzeug.exceptions import RequestEntityTooLarge

# Create a blueprint for authentication routes
auth_bp = Blueprint("auth", __name__)

# Initialize services
face_service = FaceAuthService()
biometric_service = BiometricAuthService()


@auth_bp.route("/", methods=["GET"])
def health_check():
    return jsonify({"Name": "Biometrics Backend", "status": "healthy"}), 200


@auth_bp.route("/authenticate", methods=["POST"])
def authenticate_face():
    """
    Route for face-only authentication
    """
    try:
        data = request.get_json()

        if "image" not in data:
            return jsonify({"success": False, "error": "No image data provided"}), 400

        result = face_service.verify_user(data["image"])

        if not result["success"]:
            return jsonify(result), 400

        return jsonify(result), 200

    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@auth_bp.route("/health", methods=["GET"])
def face_health_check():
    """
    Health check for face authentication service
    """
    return jsonify({"status": "Face authentication service is running"}), 200


@auth_bp.route("/biometric/authenticate", methods=["POST"])
def authenticate_biometric():
    """
    Route for combined face + voice biometric authentication
    """
    try:
        print("Received biometric authentication request")

        # Check content length before processing
        content_length = request.content_length
        max_size = 50 * 1024 * 1024  # 50MB

        if content_length and content_length > max_size:
            return (
                jsonify(
                    {
                        "success": False,
                        "error": f"File too large. Maximum size is {max_size//1024//1024}MB, received {content_length//1024//1024}MB",
                    }
                ),
                413,
            )

        print(f"Content length: {content_length}")
        print(f"Form keys: {list(request.form.keys())}")
        print(f"Files keys: {list(request.files.keys())}")

        if "image" not in request.form or "audio" not in request.files:
            missing = []
            if "image" not in request.form:
                missing.append("image")
            if "audio" not in request.files:
                missing.append("audio")
            return (
                jsonify(
                    {"success": False, "error": f"Missing data: {', '.join(missing)}"}
                ),
                400,
            )

        image_data = request.form["image"]
        audio_file = request.files["audio"]
        audio_data = audio_file.read()

        print(f"Image data length: {len(image_data)}")
        print(f"Audio data length: {len(audio_data)}")

        result = biometric_service.verify_user(image_data, audio_data)
        print(f"Biometric service result: {result}")

        if not result["success"]:
            return jsonify(result), 400

        return jsonify(result), 200
    except RequestEntityTooLarge:
        return (
            jsonify(
                {
                    "success": False,
                    "error": "File too large. Please reduce the file size and try again.",
                }
            ),
            413,
        )
    except Exception as e:
        print(f"Error in biometric authentication: {str(e)}")
        import traceback

        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500
