from flask import Flask, jsonify, request
import os
import tempfile

from config import (
    UPLOAD_DIR,
    SAVE_UPLOADED_FILES,
    FACE_THRESHOLD,
    VOICE_THRESHOLD,
    MULTIMODAL_THRESHOLD,
    PORT,
    HOST,
    DEBUG,
)

from face_verification import load_face_model, predict_face, allowed_image
from voice_verification import (
    load_speechbrain_model,
    load_audio_embeddings,
    predict_voice,
    allowed_audio,
)

app = Flask(__name__)
os.makedirs(UPLOAD_DIR, exist_ok=True)


@app.route("/", methods=["GET"])
def health():
    return jsonify(
        {
            "status": "running",
            "message": "Biometric Verification API",
            "endpoints": {
                "verify_face": "/verify-face",
                "verify_voice": "/verify-voice",
                "verify_biometric": "/verify-biometric",
            },
        }
    )


def save_uploaded_file(file_storage):
    suffix = os.path.splitext(file_storage.filename)[1]
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix, dir=UPLOAD_DIR)
    file_storage.save(tmp.name)
    return tmp.name


@app.route("/verify-face", methods=["POST"])
def verify_face():
    print("\n" + "=" * 60)
    print("[ENDPOINT] /verify-face request received")
    print("=" * 60)
    if "image" not in request.files:
        return jsonify({"success": False, "error": "No image file provided"}), 400
    f = request.files["image"]
    if f.filename == "":
        return jsonify({"success": False, "error": "Empty filename"}), 400
    if not allowed_image(f.filename):
        return jsonify({"success": False, "error": "Unsupported image type"}), 400

    path = save_uploaded_file(f)
    print(f"[UPLOAD] Image saved to: {os.path.basename(path)}")
    try:
        model = load_face_model()
        res = predict_face(path, model=model)
        verified = res["confidence"] >= FACE_THRESHOLD
        print(f"\n🔒 [DECISION] Threshold: {FACE_THRESHOLD:.4f}")
        print(
            f"{'VERIFIED' if verified else '❌ REJECTED'}: {res['person'].upper()} (confidence: {res['confidence']:.4f})"
        )
        print("=" * 60 + "\n")
        out = {
            "success": True,
            "type": "face",
            "result": {
                "verified": bool(verified),
                "person": res["person"],
                "confidence": res["confidence"],
                "similarities": res["similarities"],
                "threshold": FACE_THRESHOLD,
            },
        }
        return jsonify(out)
    finally:
        if not SAVE_UPLOADED_FILES:
            try:
                os.remove(path)
            except Exception:
                pass


@app.route("/verify-voice", methods=["POST"])
def verify_voice():
    print("\n" + "=" * 60)
    print("[ENDPOINT] /verify-voice request received")
    print("=" * 60)
    if "audio" not in request.files:
        return jsonify({"success": False, "error": "No audio file provided"}), 400
    f = request.files["audio"]
    if f.filename == "":
        return jsonify({"success": False, "error": "Empty filename"}), 400
    if not allowed_audio(f.filename):
        return jsonify({"success": False, "error": "Unsupported audio type"}), 400

    path = save_uploaded_file(f)
    print(f"📁 [UPLOAD] Audio saved to: {os.path.basename(path)}")
    try:
        audio_model = load_speechbrain_model()
        audio_embeddings = load_audio_embeddings()
        res = predict_voice(
            path, audio_model=audio_model, audio_embeddings=audio_embeddings
        )
        verified = res["confidence"] >= VOICE_THRESHOLD
        print(f"\n🔒 [DECISION] Threshold: {VOICE_THRESHOLD:.4f}")
        print(
            f"{'VERIFIED' if verified else '❌ REJECTED'}: {res['person'].upper()} (confidence: {res['confidence']:.4f})"
        )
        print("=" * 60 + "\n")
        out = {
            "success": True,
            "type": "voice",
            "result": {
                "verified": bool(verified),
                "person": res["person"],
                "confidence": res["confidence"],
                "similarities": res["similarities"],
                "threshold": VOICE_THRESHOLD,
            },
        }
        return jsonify(out)
    finally:
        if not SAVE_UPLOADED_FILES:
            try:
                os.remove(path)
            except Exception:
                pass


@app.route("/verify", methods=["POST"])
def verify_biometric():
    higher = True
    print("\n" + "=" * 60)
    print("[ENDPOINT] /verify (BIOMETRIC) request received")
    print("=" * 60)
    if "image" not in request.files or "audio" not in request.files:
        return (
            jsonify(
                {"success": False, "error": "Both image and audio files are required"}
            ),
            400,
        )

    img = request.files["image"]
    aud = request.files["audio"]
    if img.filename == "" or aud.filename == "":
        return jsonify({"success": False, "error": "Empty filename(s)"}), 400
    if not allowed_image(img.filename) or not allowed_audio(aud.filename):
        return jsonify({"success": False, "error": "Unsupported file type(s)"}), 400

    img_path = save_uploaded_file(img)
    aud_path = save_uploaded_file(aud)
    print(f"📁 [UPLOAD] Image saved to: {os.path.basename(img_path)}")
    print(f"📁 [UPLOAD] Audio saved to: {os.path.basename(aud_path)}")
    try:
        # Face
        face_model = load_face_model()
        face_res = predict_face(img_path, model=face_model)
        face_verified = face_res["confidence"] >= MULTIMODAL_THRESHOLD["face"]

        # Voice
        audio_model = load_speechbrain_model()
        audio_embeddings = load_audio_embeddings()
        voice_res = predict_voice(
            aud_path,
            audio_model=audio_model,
            audio_embeddings=audio_embeddings,
            higher=higher,
        )
        # When higher=True, accept the highest similarity person without threshold check
        if higher:
            voice_verified = True
            print(f"⚙️  [BIOMETRIC] Voice threshold bypassed (higher mode)")
        else:
            voice_verified = voice_res["confidence"] >= MULTIMODAL_THRESHOLD["voice"]

        both_verified = face_verified and voice_verified
        # Consider 'same_person' only when both modalities are verified to avoid
        # reporting a "same person" match when one modality is untrusted.
        same_person = (face_res["person"] == voice_res["person"]) and both_verified

        print(f"\n{'='*60}")
        print(f"🔒 [BIOMETRIC DECISION]")
        print(f"{'='*60}")
        print(
            f"Face: {'✅ PASS' if face_verified else '❌ FAIL'} - {face_res['person'].upper()} ({face_res['confidence']:.4f} >= {MULTIMODAL_THRESHOLD['face']:.4f})"
        )
        print(
            f"Voice: {'✅ PASS' if voice_verified else '❌ FAIL'} - {voice_res['person'].upper()} ({voice_res['confidence']:.4f} >= {MULTIMODAL_THRESHOLD['voice']:.4f})"
        )
        print(
            f"Same Person: {'✅ YES' if (face_res['person'] == voice_res['person']) else '❌ NO'}"
        )
        print(f"Both Verified: {'✅ YES' if both_verified else '❌ NO'}")

        authenticated = bool(both_verified and same_person)
        auth_name = face_res["person"] if authenticated else None

        print(
            f"\n{'🎉 AUTHENTICATED' if authenticated else '🚫 AUTHENTICATION FAILED'}: {auth_name.upper() if auth_name else 'N/A'}"
        )
        print(f"{'='*60}\n")

        # Build results arrays sorted by probability
        def to_results(similarities: dict):
            # similarities: {name: score}
            items = sorted(similarities.items(), key=lambda x: x[1], reverse=True)
            return [{"className": k, "probability": v} for k, v in items]

        image_results = to_results(face_res.get("similarities", {}))
        audio_results = to_results(voice_res.get("similarities", {}))

        out = {
            "image": {"results": image_results},
            "audio": {"results": audio_results},
            "result": {"authenticated": bool(authenticated), "name": auth_name},
        }
        return jsonify(out)
    finally:
        if not SAVE_UPLOADED_FILES:
            for p in (img_path, aud_path):
                try:
                    os.remove(p)
                except Exception:
                    pass


if __name__ == "__main__":
    app.run(host=HOST, port=PORT, debug=DEBUG)
