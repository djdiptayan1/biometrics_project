"""Pydantic models for biometric authentication API"""

from pydantic import BaseModel, Field
from typing import Optional


class BiometricAuthResponse(BaseModel):
    """Response model for biometric authentication"""

    success: bool = Field(..., description="Whether authentication was successful")
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

    class Config:
        """Pydantic configuration"""

        json_encoders = {float: lambda v: round(v, 2) if v is not None else None}
        schema_extra = {
            "example": {
                "success": True,
                "message": "Authentication successful",
                "name": "John Doe",
                "confidence": 0.95,
                "faceMatch": True,
                "voiceMatch": True,
            }
        }


class AuthErrorResponse(BaseModel):
    """Error response model for authentication failures"""

    success: bool = Field(False, description="Always false for error responses")
    message: str = Field(..., description="Error message describing what went wrong")
    name: Optional[str] = Field(None, description="Always null for errors")
    confidence: Optional[float] = Field(None, description="Always null for errors")
    faceMatch: Optional[bool] = Field(None, description="Always null for errors")
    voiceMatch: Optional[bool] = Field(None, description="Always null for errors")

    class Config:
        """Pydantic configuration"""

        schema_extra = {
            "example": {
                "success": False,
                "message": "Missing image or audio file",
                "name": None,
                "confidence": None,
                "faceMatch": None,
                "voiceMatch": None,
            }
        }


class BiometricAuthRequest(BaseModel):
    """Request model for biometric authentication (for documentation purposes)"""

    image: str = Field(..., description="Base64 encoded image or multipart file")
    audio: str = Field(..., description="Base64 encoded audio or multipart file")
    timestamp: Optional[float] = Field(None, description="Request timestamp")
    device_info: Optional[str] = Field(None, description="Device information")

    class Config:
        """Pydantic configuration"""

        schema_extra = {
            "example": {
                "image": "multipart/form-data file",
                "audio": "multipart/form-data file",
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
