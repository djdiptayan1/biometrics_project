import numpy as np
import torch
from speechbrain.pretrained import EncoderClassifier
import os
import io
import librosa
import tempfile


class VoiceAuthService:
    def __init__(self):
        self.classifier = EncoderClassifier.from_hparams(
            source="speechbrain/spkrec-ecapa-voxceleb"
        )
        # Get the absolute path to the embedding file
        current_dir = os.path.dirname(os.path.abspath(__file__))
        parent_dir = os.path.dirname(current_dir)
        embedding_path = os.path.join(parent_dir, "palash_voice.npy")
        self.palash_embedding = np.load(embedding_path)

    def cosine_similarity(self, a, b):
        return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

    def get_embedding_from_audio(self, audio_data):
        try:
            # Save audio data to a temporary file
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_file:
                temp_file.write(audio_data)
                temp_file_path = temp_file.name

            # Load audio using librosa (this handles various audio formats)
            signal, sample_rate = librosa.load(temp_file_path, sr=16000)

            # Clean up temp file
            os.unlink(temp_file_path)

            # Convert to tensor and ensure correct shape
            signal_tensor = torch.tensor(signal).unsqueeze(0)  # Add batch dimension

            # Get embedding
            embedding = (
                self.classifier.encode_batch(signal_tensor).squeeze().detach().numpy()
            )
            return embedding

        except Exception as e:
            print(f"Error processing audio: {e}")
            return None

    def verify_user(self, audio_data, threshold=0.7):
        try:
            embedding = self.get_embedding_from_audio(audio_data)

            if embedding is None:
                return {
                    "success": False,
                    "error": "Failed to process audio",
                    "authenticated": False,
                    "similarity": 0.0,
                    "result": 0,
                }

            sim = self.cosine_similarity(embedding, self.palash_embedding)
            is_authenticated = sim >= threshold

            return {
                "success": True,
                "authenticated": bool(is_authenticated),
                "similarity": float(sim),
                "result": 1 if is_authenticated else 0,
            }
        except Exception as e:
            print(f"Voice verification error: {e}")
            return {
                "success": False,
                "error": f"Voice verification failed: {str(e)}",
                "authenticated": False,
                "similarity": 0.0,
                "result": 0,
            }
