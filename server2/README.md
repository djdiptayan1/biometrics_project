
# Teachable Machine Multimodal Biometric Verification API

## Overview
This project is a Node.js Express API for multimodal biometric verification using models trained with [Google Teachable Machine](https://teachablemachine.withgoogle.com/). It supports both image and audio recognition for authentication, and is designed for clear demonstration and presentation.

---

## Features

- **Image Recognition**: Upload an image to get class predictions using a TensorFlow.js model exported from Teachable Machine.
- **Audio Recognition**: Upload a WAV or MP3 audio file for voice-based recognition. MP3s are automatically converted to WAV.
- **Multimodal Endpoint**: Send both image and audio in a single request for combined biometric verification.
- **Detailed Console Logging**: Every step of preprocessing, prediction, and cleanup is logged for transparency and presentation.

---

## Teachable Machine: Training & Export

1. Go to [Teachable Machine](https://teachablemachine.withgoogle.com/).
2. Choose Image or Audio Project.
3. Collect and label your training data (images or audio samples).
4. Train the model in the browser.
5. Export the model for TensorFlow.js:
   - Click "Export Model" > "TensorFlow.js".
   - Download and place the exported files (`model.json`, `metadata.json`, `weights.bin`) in the `models/ImageModel/` or `models/AudioModel/` directory.

---

## How the API Works

### Image Recognition Flow
1. **Model Loading**: Loads the TensorFlow.js model and metadata (class labels) from disk.
2. **Image Upload**: Receives an image file via POST request.
3. **Preprocessing**:
   - Decodes the image buffer.
   - Resizes to 224x224 pixels.
   - Normalizes pixel values to [0, 1].
   - Expands dimensions to match model input shape.
4. **Prediction**: Runs the preprocessed image through the model to get class probabilities.
5. **Result**: Returns sorted class probabilities as JSON.
6. **Cleanup**: Deletes temporary files and disposes tensors.

### Audio Recognition Flow
1. **Model Loading**: Loads the TensorFlow.js model and metadata (class labels) from disk.
2. **Audio Upload**: Receives a WAV or MP3 file via POST request.
3. **MP3 Conversion**: If MP3, converts to WAV using ffmpeg.
4. **Preprocessing**:
   - Reads and decodes the WAV file.
   - Ensures 1 second (16,000 samples) at 16kHz.
   - Computes a spectrogram using Short-Time Fourier Transform (STFT): 43 frames, 232 bins.
   - Normalizes and reshapes to [1, 43, 232, 1] for the model.
5. **Prediction**: Runs the spectrogram through the model to get class probabilities.
6. **Result**: Returns sorted class probabilities as JSON.
7. **Cleanup**: Deletes temporary files and disposes tensors.

---


## API Routes

### POST `/predict`
- **Description:** Multimodal endpoint. Accepts both image and audio files in a single request. Returns predictions for each.
- **Body:** `form-data` with keys:
  - `image` (File, optional): Image file for image recognition
  - `audio` (File, optional): Audio file (WAV or MP3) for audio recognition
- **Response:** JSON with `image` and/or `audio` prediction results.

### POST `/image/predict`
- **Description:** Image-only endpoint. Accepts a single image file and returns class predictions.
- **Body:** `form-data` with key:
  - `image` (File): Image file for image recognition
- **Response:** JSON with image prediction results.

### POST `/audio/predict`
- **Description:** Audio-only endpoint. Accepts a single audio file (WAV or MP3) and returns class predictions.
- **Body:** `form-data` with key:
  - `audio` (File): Audio file for audio recognition
- **Response:** JSON with audio prediction results.

### GET `/`
- **Description:** Health check and project info endpoint. Returns a welcome message.

---

## API Usage

### 1. Start the Server
```bash
npm install
node index.js
```

### 2. Test with Postman or Client
- **POST** `http://localhost:3000/predict`
- Body: `form-data`
  - Key: `image` (File) — your image file
  - Key: `audio` (File) — your audio file (WAV or MP3)
- Response: JSON with individual and combined results

#### Example Response
```json
{
  "image": {
    "results": [
      { "className": "diptayan", "probability": 0.97 },
      { "className": "rudrajit", "probability": 0.02 },
      { "className": "null", "probability": 0.01 }
    ]
  },
  "audio": {
    "results": [
      { "className": "Background Noise", "probability": 0.80 },
      { "className": "diptayan", "probability": 0.15 },
      { "className": "rudrajit", "probability": 0.05 }
    ]
  }
}
```

---

## Project Structure

```
server2/
├── controller/
│   ├── imageModel.js      # Image model logic (detailed logging)
│   └── audioModel.js      # Audio model logic (detailed logging)
├── routes/
│   ├── image.js           # Image API routes
│   └── audio.js           # Audio API routes
├── models/
│   ├── ImageModel/        # Teachable Machine image model files
│   └── AudioModel/        # Teachable Machine audio model files
├── index.js               # Main Express server
└── ...
```

---

## Extending for Multimodal Authentication

- Combine the top predictions from both image and audio for robust biometric verification.
- Add authentication logic in the `/predict` endpoint to accept or reject users based on thresholds.

---

## Requirements
- Node.js
- npm packages: `express`, `multer`, `@tensorflow/tfjs-node`, `node-wav`, `fluent-ffmpeg`, `@ffmpeg-installer/ffmpeg`, `fft-js`

---

## References
- [Teachable Machine Docs](https://github.com/googlecreativelab/teachablemachine-community/tree/master/libraries/image)
- [Teachable Machine Audio Docs](https://github.com/googlecreativelab/teachablemachine-community/tree/master/libraries/audio)
- [TensorFlow.js](https://www.tensorflow.org/js)