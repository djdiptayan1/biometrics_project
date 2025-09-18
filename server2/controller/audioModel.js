
const tf = require('@tensorflow/tfjs-node');
const fs = require('fs');
const path = require('path');
const wav = require('node-wav');
const ffmpeg = require('fluent-ffmpeg');
const ffmpegInstaller = require('@ffmpeg-installer/ffmpeg');
const fft = require('fft-js').fft;
const fftUtil = require('fft-js').util;
ffmpeg.setFfmpegPath(ffmpegInstaller.path);

const MODEL_PATH = path.join(__dirname, '../models/AudioModel/model.json');
const METADATA_PATH = path.join(__dirname, '../models/AudioModel/metadata.json');
let model = null;
let labels = [];

async function loadModel() {
    if (!model) {
        console.log('[AudioModel] Step 1: Loading model from', MODEL_PATH);
        model = await tf.loadLayersModel('file://' + MODEL_PATH);
        console.log('[AudioModel] Step 2: Loading metadata from', METADATA_PATH);
        const metadata = JSON.parse(fs.readFileSync(METADATA_PATH, 'utf8'));
        labels = metadata.labels || metadata.words || metadata.wordLabels || [];
        console.log('[AudioModel] Step 3: Model loaded. Classes:', labels);
    }
}


exports.predictAudio = async (req, res) => {
    try {
        await loadModel();
        let audioPath = req.file.path;
        console.log('[AudioModel] Step 4: Received audio file:', audioPath);

        // If file is mp3, convert to wav
        let wavPath = audioPath;
        if (req.file.mimetype === 'audio/mpeg' || req.file.originalname.endsWith('.mp3')) {
            wavPath = audioPath + '.wav';
            console.log('[AudioModel] Step 5: Converting MP3 to WAV...');
            await new Promise((resolve, reject) => {
                ffmpeg(audioPath)
                    .toFormat('wav')
                    .on('end', resolve)
                    .on('error', reject)
                    .save(wavPath);
            });
            console.log('[AudioModel] Step 6: Conversion complete:', wavPath);
        }

        console.log('[AudioModel] Step 7: Reading WAV audio buffer...');
        const audioBuffer = fs.readFileSync(wavPath);
        // Decode WAV file
        console.log('[AudioModel] Step 8: Decoding WAV file...');
        const result = wav.decode(audioBuffer);
        const audioData = result.channelData[0];
        // Teachable Machine audio expects 1 second (16k samples) input
        const inputLength = 16000;
        let input = audioData;
        if (input.length > inputLength) input = input.slice(0, inputLength);
        if (input.length < inputLength) {
            // Pad with zeros
            const pad = new Float32Array(inputLength);
            pad.set(input);
            input = pad;
        }
        console.log('[AudioModel] Step 9: Audio waveform ready. Length:', input.length);

        // --- Spectrogram (STFT) preprocessing ---
        // Parameters for TM: 43 frames, 232 bins, 1 channel
        const frameLength = 512; // samples per frame
        const frameStep = 375;   // hop length (samples)
        const numFrames = 43;
        const numBins = 232;
        let spectrogram = [];
        for (let i = 0; i < numFrames; i++) {
            const start = i * frameStep;
            const frame = input.slice(start, start + frameLength);
            // Zero pad if needed
            let padded = frame;
            if (frame.length < frameLength) {
                padded = new Float32Array(frameLength);
                padded.set(frame);
            }
            // FFT
            const phasors = fft(Array.from(padded));
            const mags = fftUtil.fftMag(phasors);
            // Only take first numBins
            spectrogram.push(mags.slice(0, numBins));
        }
        console.log('[AudioModel] Step 10: Spectrogram computed. Shape:', [numFrames, numBins]);
        // Normalize spectrogram (optional, for stability)
        let specArr = spectrogram.flat();
        const max = Math.max(...specArr);
        const min = Math.min(...specArr);
        specArr = specArr.map(v => (v - min) / (max - min + 1e-6));
        // Reshape to [1, 43, 232, 1]
        const inputTensor = tf.tensor4d(specArr, [1, numFrames, numBins, 1]);
        console.log('[AudioModel] Step 11: Audio preprocessed (spectrogram). Shape:', inputTensor.shape);

        // Predict
        console.log('[AudioModel] Step 12: Running prediction...');
        const prediction = model.predict(inputTensor);
        const probabilities = prediction.dataSync();
        const results = labels.map((label, i) => ({
            className: label,
            probability: probabilities[i]
        }));
        results.sort((a, b) => b.probability - a.probability);
        console.log('[AudioModel] Step 13: Prediction results:', results);

        // Clean up
        fs.unlinkSync(audioPath);
        if (wavPath !== audioPath) fs.unlinkSync(wavPath);
        tf.dispose([inputTensor, prediction]);
        console.log('[AudioModel] Step 14: Cleaned up temporary files and tensors.');

        res.json({ results });
    } catch (err) {
        console.error('[AudioModel] Error:', err);
        res.status(500).json({ error: err.message });
    }
};
