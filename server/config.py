import os


class Config:
    """Base configuration class"""

    DEBUG = True
    HOST = "0.0.0.0"
    PORT = 3000
    # Set maximum file upload size to 50MB (audio files can be large)
    MAX_CONTENT_LENGTH = 50 * 1024 * 1024  # 50MB


class DevelopmentConfig(Config):
    """Development configuration"""

    DEBUG = True


class ProductionConfig(Config):
    """Production configuration"""

    DEBUG = False


# Configuration mapping
config = {
    "development": DevelopmentConfig,
    "production": ProductionConfig,
    "default": DevelopmentConfig,
}
