import os

# Base directory
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Embedding paths
EMBEDDING_DIR = os.path.join(BASE_DIR, "embedding")
FACE_EMBEDDINGS = os.path.join(EMBEDDING_DIR, "auth_model.pth")

VOICE_EMBEDDINGS = os.path.join(EMBEDDING_DIR, "audio_embeddings.pth")

# Upload directory
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Debug settings
SAVE_UPLOADED_FILES = True  # Set to False in production to auto-delete files
DEBUG_DIR = os.path.join(BASE_DIR, "debug_uploads")
if SAVE_UPLOADED_FILES:
    os.makedirs(DEBUG_DIR, exist_ok=True)

# Verification thresholds
FACE_THRESHOLD = 0.65
VOICE_THRESHOLD = 0.012

# Multimodal threshold (both face and voice must pass)
MULTIMODAL_THRESHOLD = {"face": FACE_THRESHOLD, "voice": VOICE_THRESHOLD}

# Allowed file extensions
ALLOWED_IMAGE_EXTENSIONS = {"png", "jpg", "jpeg"}
ALLOWED_AUDIO_EXTENSIONS = {"wav", "mp3"}

# Server config
HOST = "0.0.0.0"
PORT = 3000
DEBUG = True
