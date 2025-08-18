from services.face_auth_service import FaceAuthService
from services.voice_auth_service import VoiceAuthService

class BiometricAuthService:
    def __init__(self):
        self.face_service = FaceAuthService()
        self.voice_service = VoiceAuthService()

    def verify_user(self, image_data, audio_data, face_threshold=0.7, voice_threshold=0.7):
        face_result = self.face_service.verify_user(image_data, threshold=face_threshold)
        voice_result = self.voice_service.verify_user(audio_data, threshold=voice_threshold)

        if not face_result["success"]:
            return {"success": False, "error": "Face verification failed", "face_result": face_result}

        if not voice_result["success"]:
            return {"success": False, "error": "Voice verification failed", "voice_result": voice_result}

        is_authenticated = face_result["authenticated"] and voice_result["authenticated"]

        return {
            # "success": True,
            "success": bool(is_authenticated),
            "message": "Authentication successful" if is_authenticated else "Authentication failed",
            "name": "Palash Shah" if is_authenticated else None,
            "confidence": float((face_result["similarity"] + voice_result["similarity"]) / 2),
            "faceMatch": face_result["authenticated"],
            "voiceMatch": voice_result["authenticated"],
            "face_similarity": float(face_result["similarity"]),
            "voice_similarity": float(voice_result["similarity"]),
            "result": 1 if is_authenticated else 0
        }
