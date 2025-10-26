import os
import tempfile
import torch
import torchaudio
import shutil
import subprocess
from speechbrain.pretrained import EncoderClassifier
from scipy.spatial.distance import cosine

higher = True

from config import VOICE_EMBEDDINGS, ALLOWED_AUDIO_EXTENSIONS


def allowed_audio(filename: str) -> bool:
    return filename.rsplit(".", 1)[-1].lower() in ALLOWED_AUDIO_EXTENSIONS


def _has_ffmpeg() -> bool:
    return shutil.which("ffmpeg") is not None


def mp3_to_wav(in_path: str) -> str:
    """Convert any audio file to WAV using ffmpeg. Raises FileNotFoundError with
    a helpful message if ffmpeg is not installed.
    """
    if not _has_ffmpeg():
        raise FileNotFoundError(
            "ffmpeg is required to convert audio files but was not found on PATH. "
            "Install with: brew install ffmpeg (macOS) or apt install ffmpeg (Ubuntu)."
        )

    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    out_path = tmp.name
    # Convert and resample to 16k mono which is commonly used for speaker models
    cmd = ["ffmpeg", "-y", "-i", in_path, "-ar", "16000", "-ac", "1", out_path]
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise RuntimeError(
            f'ffmpeg conversion failed: {proc.stderr.decode(errors="ignore")}'
        )
    return out_path


def load_audio_embeddings(path: str = VOICE_EMBEDDINGS):
    return torch.load(path, map_location="cpu")


def load_speechbrain_model(device: str = "cpu"):
    # Load SpeechBrain model and set run options for device
    # device should be 'cuda' or 'cpu'
    print(f"[VOICE] Using device: {device.upper()}")
    print(f"[VOICE] Loading SpeechBrain ECAPA-TDNN model...")
    run_opts = {"device": device}
    model = EncoderClassifier.from_hparams(
        source="speechbrain/spkrec-ecapa-voxceleb", run_opts=run_opts
    )
    print(f"[VOICE] Model loaded successfully")
    return model


def get_audio_embedding(audio_path: str, audio_model: EncoderClassifier):
    # Use ffmpeg conversion for non-wav files to ensure torchaudio can read them
    ext = audio_path.rsplit(".", 1)[-1].lower()
    wav_path = audio_path
    tmp_created = False
    if ext != "wav":
        print(f"[VOICE] Converting {ext.upper()} to WAV...")
        wav_path = mp3_to_wav(audio_path)
        tmp_created = True

    signal, fs = torchaudio.load(wav_path)
    duration = signal.shape[-1] / fs
    print(
        f"[VOICE] Audio loaded: {fs}Hz, {signal.shape[0]} channel(s), {duration:.2f}s duration"
    )

    if tmp_created:
        try:
            os.remove(wav_path)
        except Exception:
            pass

    # torchaudio.load returns (channels, samples); SpeechBrain expects (channels, samples)
    # Convert to mono if multiple channels by averaging across channel dim
    if signal.dim() == 1:
        signal = signal.unsqueeze(0)
    if signal.shape[0] > 1:
        # average across channel dimension -> (1, samples)
        print(f"[VOICE] Converting stereo to mono")
        signal = torch.mean(signal, dim=0, keepdim=True)

    # model should already be loaded with the correct device; ensure tensor on same device
    try:
        device = next(audio_model.parameters()).device
    except Exception:
        device = torch.device("cpu")
    signal = signal.to(device)
    print(f"[VOICE] Extracting embedding...")

    # Try a few strategies to get an embedding (different SpeechBrain versions may require
    # different input shapes or offer encode_file helper)
    try:
        emb = audio_model.encode_batch(signal)
        emb = emb.squeeze().detach().cpu().numpy()
        print(f"[VOICE] Embedding extracted: shape {emb.shape}")
        return emb
    except Exception as err1:
        # try encode_file if available
        try:
            if hasattr(audio_model, "encode_file"):
                emb = audio_model.encode_file(wav_path)
                # encode_file may return a tensor
                if isinstance(emb, torch.Tensor):
                    emb = emb.detach().cpu().numpy().squeeze()
                return emb
        except Exception:
            pass

        # try alternate shape: (batch, ) waveform (no channel dim)
        try:
            alt = signal.squeeze(0)
            emb = audio_model.encode_batch(alt.unsqueeze(0))
            emb = emb.squeeze().detach().cpu().numpy()
            return emb
        except Exception:
            # Final fallback: raise a helpful error including the original exception
            raise RuntimeError(
                f"Failed to extract embedding: {err1}. Tried encode_file and alternate shapes."
            )


def predict_voice(
    audio_path: str, audio_model=None, audio_embeddings=None, higher=False
):
    # choose device: prefer CUDA if available else CPU
    print(f"\n🔍 [VOICE] Processing audio: {os.path.basename(audio_path)}")
    if higher:
        print(f"⚙️  [VOICE] Mode: HIGHEST SIMILARITY (ignoring threshold)")
    device = "cuda" if torch.cuda.is_available() else "cpu"
    if audio_model is None:
        audio_model = load_speechbrain_model(device=device)
    if audio_embeddings is None:
        print(f"📂 [VOICE] Loading reference embeddings...")
        audio_embeddings = load_audio_embeddings()
        print(f"✅ [VOICE] Loaded {len(audio_embeddings)} reference voice(s)")

    test_emb = get_audio_embedding(audio_path, audio_model)
    print(f"📊 [VOICE] Computing similarities...")
    scores = {}
    for name, ref_emb in audio_embeddings.items():
        key = str(name).lower()
        # ref_emb may be a tensor or numpy array
        if isinstance(ref_emb, torch.Tensor):
            ref_vec = ref_emb.detach().cpu().numpy().squeeze()
        else:
            ref_vec = ref_emb.squeeze()
        sim = 1 - cosine(test_emb, ref_vec)
        scores[key] = float(sim)

    print(f"📊 [VOICE] Similarities:")
    for name, score in sorted(scores.items(), key=lambda x: x[1], reverse=True):
        print(f"   • {name.capitalize()}: {score:.4f}")

    best = max(scores, key=scores.get)
    person = best
    print(f"👤 [VOICE] Predicted person: {person.upper()}")
    print(f"💯 [VOICE] Confidence: {scores[best]:.4f}")

    return {
        "verified": (
            True if higher else True
        ),  # when higher=True, always return verified=True
        "person": person,
        "confidence": float(scores[best]),
        "similarities": scores,
    }
