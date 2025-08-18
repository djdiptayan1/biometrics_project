"""Pydantic models for biometric authentication API"""

from pydantic import BaseModel, Field
from typing import Optional


class BiometricAuthResponse(BaseModel):
    """Response model for biometric authentication"""

    success: bool = Field(..., description="Whether authentication was successful")
    authenticated: Optional[bool] = Field(
        None, description="Whether the user was authenticated"
    )
    message: str = Field(
        ..., description="Human-readable message about the authentication result"
    )
    name: Optional[str] = Field(None, description="Name of the authenticated person")
    confidence: Optional[float] = Field(
        None, ge=0.0, le=1.0, description="Overall confidence score (0.0 to 1.0)"
    )
    faceMatch: Optional[bool] = Field(
        None, description="Whether face biometric matched"
    )
    voiceMatch: Optional[bool] = Field(
        None, description="Whether voice biometric matched"
    )
    face_similarity: Optional[float] = Field(
        None, ge=0.0, le=1.0, description="Face similarity score (0.0 to 1.0)"
    )
    voice_similarity: Optional[float] = Field(
        None, ge=0.0, le=1.0, description="Voice similarity score (0.0 to 1.0)"
    )
    result: Optional[int] = Field(
        None, description="Result flag: 1 for success, 0 for failure"
    )
    similarity: Optional[float] = Field(
        None,
        ge=0.0,
        le=1.0,
        description="Similarity score for single biometric (face-only)",
    )

    class Config:
        """Pydantic configuration"""

        json_encoders = {float: lambda v: round(v, 3) if v is not None else None}
        schema_extra = {
            "example": {
                "success": True,
                "authenticated": True,
                "message": "Authentication successful",
                "name": "Palash Shah",
                "confidence": 0.856,
                "faceMatch": True,
                "voiceMatch": True,
                "face_similarity": 0.872,
                "voice_similarity": 0.840,
                "result": 1,
            }
        }


class FaceOnlyAuthResponse(BaseModel):
    """Response model for face-only authentication"""

    success: bool = Field(..., description="Whether authentication was successful")
    authenticated: Optional[bool] = Field(
        None, description="Whether the user was authenticated"
    )
    similarity: Optional[float] = Field(
        None, ge=0.0, le=1.0, description="Face similarity score (0.0 to 1.0)"
    )
    result: Optional[int] = Field(
        None, description="Result flag: 1 for success, 0 for failure"
    )
    message: Optional[str] = Field(None, description="Optional message")

    class Config:
        """Pydantic configuration"""

        json_encoders = {float: lambda v: round(v, 3) if v is not None else None}
        schema_extra = {
            "example": {
                "success": True,
                "authenticated": True,
                "similarity": 0.872,
                "result": 1,
            }
        }


class AuthErrorResponse(BaseModel):
    """Error response model for authentication failures"""

    success: bool = Field(False, description="Always false for error responses")
    error: Optional[str] = Field(
        None, description="Error message describing what went wrong"
    )
    message: Optional[str] = Field(None, description="Alternative error message field")
    authenticated: Optional[bool] = Field(None, description="Always null for errors")
    name: Optional[str] = Field(None, description="Always null for errors")
    confidence: Optional[float] = Field(None, description="Always null for errors")
    faceMatch: Optional[bool] = Field(None, description="Always null for errors")
    voiceMatch: Optional[bool] = Field(None, description="Always null for errors")
    face_result: Optional[dict] = Field(
        None, description="Face verification result details"
    )
    voice_result: Optional[dict] = Field(
        None, description="Voice verification result details"
    )

    class Config:
        """Pydantic configuration"""

        schema_extra = {
            "example": {
                "success": False,
                "error": "Image or audio data missing",
                "authenticated": None,
                "name": None,
                "confidence": None,
                "faceMatch": None,
                "voiceMatch": None,
            }
        }


class BiometricAuthRequest(BaseModel):
    """Request model for biometric authentication (for documentation purposes)"""

    image: str = Field(
        ..., description="Base64 encoded image data or multipart form field"
    )
    audio: str = Field(..., description="Audio file as multipart form upload")
    timestamp: Optional[float] = Field(None, description="Request timestamp")
    device_info: Optional[str] = Field(None, description="Device information")

    class Config:
        """Pydantic configuration"""

        schema_extra = {
            "example": {
                "image": "base64 encoded image data or multipart form field",
                "audio": "multipart/form-data audio file",
                "timestamp": 1692364800.0,
                "device_info": "iOS 16.0",
            }
        }


class FaceAuthRequest(BaseModel):
    """Request model for face-only authentication"""

    image: str = Field(..., description="Base64 encoded image data")
    timestamp: Optional[float] = Field(None, description="Request timestamp")
    device_info: Optional[str] = Field(None, description="Device information")

    class Config:
        """Pydantic configuration"""

        schema_extra = {
            "example": {
                "image": "base64 encoded image data",
                "timestamp": 1692364800.0,
                "device_info": "iOS 16.0",
            }
        }


# Validation helpers
class FileValidation:
    """File validation utilities"""

    VALID_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".gif"}
    VALID_AUDIO_EXTENSIONS = {".m4a", ".wav", ".mp3", ".aac", ".flac"}

    @classmethod
    def is_valid_image(cls, filename: str) -> bool:
        """Check if the uploaded file is a valid image format"""
        if not filename:
            return False
        return any(filename.lower().endswith(ext) for ext in cls.VALID_IMAGE_EXTENSIONS)

    @classmethod
    def is_valid_audio(cls, filename: str) -> bool:
        """Check if the uploaded file is a valid audio format"""
        if not filename:
            return False
        return any(filename.lower().endswith(ext) for ext in cls.VALID_AUDIO_EXTENSIONS)


# Health check response models
class HealthCheckResponse(BaseModel):
    """Response model for health check endpoints"""

    status: str = Field(..., description="Service status")
    Name: Optional[str] = Field(None, description="Service name")

    class Config:
        """Pydantic configuration"""

        schema_extra = {"example": {"Name": "Biometrics Backend", "status": "healthy"}}
