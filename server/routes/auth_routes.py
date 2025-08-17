from flask import Blueprint, jsonify
from controllers.auth_controller import AuthController

# Create a blueprint for authentication routes
auth_bp = Blueprint("auth", __name__)


@auth_bp.route("/", methods=["GET"])
def health_check():
    return jsonify({"Name": "Biometrics Backend", "status": "healthy"}), 200


@auth_bp.route("/authenticate", methods=["POST"])
def authenticate():
    """
    Route for biometric authentication
    """
    return AuthController.authenticate()
