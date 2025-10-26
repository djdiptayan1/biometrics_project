# Biometric Verification API

A Flask-based REST API for biometric verification using face recognition and voice authentication.

## Features

- **Face Verification**: Verify identity using facial images (PNG, JPG, JPEG) with MobileNetV2
- **Voice Verification**: Verify identity using voice recordings (WAV, MP3) with SpeechBrain ECAPA-TDNN
- **Multimodal Verification**: Combined face and voice authentication for enhanced security
- **Pre-trained Models**: Uses trained models for immediate deployment
- **Real-time Processing**: Fast inference with GPU support (CUDA/MPS)

## Technology Stack

- **Flask**: Web framework
- **MobileNetV2**: Lightweight face recognition model
- **SpeechBrain ECAPA-TDNN**: State-of-the-art speaker recognition
- **PyTorch**: Deep learning framework
- **Torchaudio**: Audio processing
- **FFmpeg**: Audio format conversion (required for MP3/M4A support)

## Installation

1. **Install Python dependencies**:
```bash
cd server
pip install -r requirements.txt
```

2. **Download SpeechBrain model** (will happen automatically on first run):
   - The `speechbrain/spkrec-ecapa-voxceleb` model will be downloaded when you first start the server

## Project Structure

```
server/
├── app.py                       # Main Flask application
├── config.py                    # Configuration settings
├── face_verification.py         # Face verification logic (MobileNetV2)
├── voice_verification.py        # Voice verification logic (SpeechBrain ECAPA-TDNN)
├── requirements.txt             # Python dependencies
├── embedding/                   # Model weights and embeddings
│   ├── auth_model.pth          # Face recognition model (MobileNetV2)
│   ├── audio_embeddings.pth    # Voice reference embeddings
│   ├── diptayan_embedding.npy  # Face embedding for Diptayan
│   ├── palash_embedding.npy    # Face embedding for Palash
│   ├── diptayan_voice.npy      # Voice embedding for Diptayan
│   └── palash_voice.npy        # Voice embedding for Palash
├── pretrained_models/          # SpeechBrain cached models
│   └── EncoderClassifier-*/    # ECAPA-TDNN model cache
└── uploads/                    # Temporary upload directory
```

## Configuration

Edit `config.py` to adjust:
- **Thresholds**: `FACE_THRESHOLD` (default: 0.65), `VOICE_THRESHOLD` (default: 0.012)
- **Embeddings**: Face model (`auth_model.pth`), Voice embeddings (`audio_embeddings.pth`)
- **Server settings**: Host (default: 0.0.0.0), Port (default: 3000), Debug mode
- **File Storage**: `SAVE_UPLOADED_FILES` (default: True for debugging)

## Running the Server

```bash
cd server
python app.py
```

The server will start on `http://0.0.0.0:3000` by default.

## API Endpoints

### 1. Health Check
```http
GET /
```

**Response**:
```json
{
  "status": "running",
  "message": "Biometric Verification API",
  "endpoints": {...}
}
```

### 2. Face Verification
```http
POST /verify-face
Content-Type: multipart/form-data
```

**Parameters**:
- `image`: Image file (PNG, JPG, JPEG)

**Response**:
```json
{
  "success": true,
  "type": "face",
  "result": {
    "verified": true,
    "person": "diptayan",
    "confidence": 0.9234,
    "similarities": {
      "diptayan": 0.9234,
      "palash": 0.0766
    },
    "threshold": 0.65
  }
}
```

### 3. Voice Verification
```http
POST /verify-voice
Content-Type: multipart/form-data
```

**Parameters**:
- `audio`: Audio file (WAV, MP3)

**Response**:
```json
{
  "success": true,
  "type": "voice",
  "result": {
    "verified": true,
    "person": "palash",
    "confidence": 0.8456,
    "similarities": {
      "palash": 0.8456,
      "diptayan": 0.3214
    },
    "threshold": 0.012
  }
}
```

### 4. Biometric (Face + Voice) Verification

```http
POST /verify
Content-Type: multipart/form-data
```

**Parameters**:
- `image`: Image file (PNG, JPG, JPEG)
- `audio`: Audio file (WAV, MP3)

**Response**:
```json
{
  "image": {
    "results": [
      {
        "className": "diptayan",
        "probability": 0.9234
      },
      {
        "className": "palash",
        "probability": 0.0766
      }
    ]
  },
  "audio": {
    "results": [
      {
        "className": "diptayan",
        "probability": 0.8456
      },
      {
        "className": "palash",
        "probability": 0.3214
      }
    ]
  },
  "result": {
    "authenticated": true,
    "name": "diptayan"
  }
}
```

**Note**: This endpoint uses a "higher mode" for voice verification, which accepts the highest similarity match without strict threshold checking. Both face and voice must identify the same person for successful authentication.

## Usage Examples

### Using cURL

**Face Verification**:
```bash
curl -X POST http://localhost:3000/verify-face \
  -F "image=@path/to/image.jpg"
```

**Voice Verification**:
```bash
curl -X POST http://localhost:3000/verify-voice \
  -F "audio=@path/to/audio.wav"
```

**Biometric Verification**:
```bash
curl -X POST http://localhost:3000/verify \
  -F "image=@path/to/image.jpg" \
  -F "audio=@path/to/audio.wav"
```

### Using Python Requests

```python
import requests

# Face verification
with open('image.jpg', 'rb') as f:
    response = requests.post(
        'http://localhost:3000/verify-face',
        files={'image': f}
    )
    print(response.json())

# Voice verification
with open('audio.wav', 'rb') as f:
    response = requests.post(
        'http://localhost:3000/verify-voice',
        files={'audio': f}
    )
    print(response.json())

# Biometric verification
with open('image.jpg', 'rb') as img, open('audio.wav', 'rb') as aud:
    response = requests.post(
        'http://localhost:3000/verify',
        files={'image': img, 'audio': aud}
    )
    print(response.json())
```

### Using JavaScript (Fetch API)

```javascript
// Face verification
const formData = new FormData();
formData.append('image', imageFile);

fetch('http://localhost:3000/verify-face', {
  method: 'POST',
  body: formData
})
.then(response => response.json())
.then(data => console.log(data));

// Biometric verification
const bioFormData = new FormData();
bioFormData.append('image', imageFile);
bioFormData.append('audio', audioFile);

fetch('http://localhost:3000/verify', {
  method: 'POST',
  body: bioFormData
})
.then(response => response.json())
.then(data => console.log(data));
```

## Adding New Reference Embeddings

### For Face Recognition

The current implementation uses a pre-trained MobileNetV2 model (`auth_model.pth`) that is trained to recognize specific individuals (Diptayan and Palash). To add new persons:

1. Collect training images for the new person
2. Retrain the MobileNetV2 model with the new person's images
3. Update the class mapping in `face_verification.py` if needed
4. Save the updated model as `auth_model.pth`

### For Voice Recognition

The system uses SpeechBrain ECAPA-TDNN embeddings stored in `audio_embeddings.pth`. To add a new person:

1. Create voice embeddings using the voice verification script:
```python
from voice_verification import load_speechbrain_model, get_audio_embedding
import torch

audio_model = load_speechbrain_model()
embedding = get_audio_embedding("path/to/new_person_voice.wav", audio_model)

# Load existing embeddings
embeddings = torch.load("embedding/audio_embeddings.pth")

# Add new person
embeddings["new_person"] = torch.tensor(embedding)

# Save updated embeddings
torch.save(embeddings, "embedding/audio_embeddings.pth")
```

2. The system will automatically recognize the new person in future requests

## Error Handling

All endpoints return error responses in the following format:

```json
{
  "success": false,
  "error": "Error message",
  "traceback": "..." // Only in DEBUG mode
}
```

## Security Considerations

- **HTTPS**: Deploy with HTTPS in production
- **Rate Limiting**: Add rate limiting to prevent abuse
- **File Validation**: The API validates file types and uses secure filenames
- **Temporary Files**: Uploaded files are deleted after processing
- **CORS**: Configure CORS appropriately for your frontend domain

## Performance Tips

- Models are loaded once at startup and reused
- Files are processed and deleted immediately
- Consider using a GPU for faster inference in production

## Troubleshooting

**Issue**: Models take long to load  
**Solution**: This is normal on first run. SpeechBrain models will be downloaded and cached. Subsequent runs will be faster.

**Issue**: Low face recognition accuracy  
**Solution**: Ensure good lighting and clear face visibility. The model is trained on specific individuals (Diptayan and Palash).

**Issue**: Low voice recognition accuracy  
**Solution**: Use clear audio recordings with minimal background noise. Adjust `VOICE_THRESHOLD` in `config.py` if needed. The current threshold (0.012) is set very low for higher mode operation.

**Issue**: FFmpeg not found error  
**Solution**: Install FFmpeg for audio format conversion:
- macOS: `brew install ffmpeg`
- Ubuntu: `apt install ffmpeg`

**Issue**: Out of memory errors  
**Solution**: Reduce batch processing or use a machine with more RAM/GPU memory. For MPS (Apple Silicon), ensure you're running the latest PyTorch version.

**Issue**: MPS/CUDA not being used  
**Solution**: 
- For Apple Silicon: Install PyTorch with MPS support: `pip install torch torchvision torchaudio`
- For NVIDIA GPU: Install CUDA-enabled PyTorch

## Model Details

### Face Recognition
- **Architecture**: MobileNetV2 with custom classifier
- **Input**: 224x224 RGB images
- **Output**: Binary classification (Diptayan vs Palash)
- **Device Support**: CPU, CUDA, MPS (Apple Silicon)

### Voice Recognition
- **Architecture**: SpeechBrain ECAPA-TDNN (speechbrain/spkrec-ecapa-voxceleb)
- **Input**: 16kHz mono audio
- **Similarity Metric**: Cosine similarity between embeddings
- **Mode**: Higher similarity mode (accepts highest match without strict threshold)