import cv2
import numpy as np
from mtcnn import MTCNN
from PIL import Image
from keras_facenet import FaceNet
import base64
import io
import os


class FaceAuthService:
    def __init__(self):
        self.detector = MTCNN()
        self.embedder = FaceNet()

        # Get the absolute path to the embedding file
        current_dir = os.path.dirname(os.path.abspath(__file__))
        parent_dir = os.path.dirname(current_dir)
        embedding_path = os.path.join(parent_dir, "palash_embedding.npy")
        self.palash_embedding = np.load(embedding_path)

    def cosine_similarity(self, a, b):
        return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

    def get_embedding_from_image(self, image_data, target_size=(160, 160)):
        if isinstance(image_data, str):  # If Base64 string
            image_bytes = base64.b64decode(image_data)
            image = Image.open(io.BytesIO(image_bytes))
            frame = np.array(image)
        else:
            frame = image_data

        detections = self.detector.detect_faces(frame)
        if len(detections) == 0:
            return None

        x, y, w, h = detections[0]["box"]
        x, y = max(x, 0), max(y, 0)

        face_crop = frame[y : y + h, x : x + w]
        face_resized = Image.fromarray(face_crop).resize(target_size)

        face_array = np.asarray(face_resized)
        embedding = self.embedder.embeddings([face_array])[0]
        return embedding

    def verify_user(self, image_data, threshold=0.70):
        embedding = self.get_embedding_from_image(image_data)

        if embedding is None:
            return {"success": False, "error": "No face detected", "similarity": 0}

        sim = self.cosine_similarity(embedding, self.palash_embedding)
        is_authenticated = sim >= threshold

        return {
            "success": True,
            "authenticated": bool(is_authenticated),
            "similarity": float(sim),
            "result": 1 if is_authenticated else 0,
        }
