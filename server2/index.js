const express = require('express');
const app = express();
const port = 3000;


// Import routes
const imageRoutes = require('./routes/image');
const audioRoutes = require('./routes/audio');
const { predictImage } = require('./controller/imageModel');
const { predictAudio } = require('./controller/audioModel');
const multer = require('multer');
const upload = multer({ dest: 'uploads/' });

// Use routes
app.use('/image', imageRoutes);
app.use('/audio', audioRoutes);


// Import authenticate utility
const { authenticate } = require('./utils/authenticate');

// Multimodal endpoint: accepts both image and audio
app.post('/predict', upload.fields([
    { name: 'image', maxCount: 1 },
    { name: 'audio', maxCount: 1 }
]), async (req, res) => {
    let imageResult = null;
    let audioResult = null;
    let errors = {};

    // Predict image if present
    if (req.files && req.files.image) {
        try {
            req.file = req.files.image[0];
            imageResult = await new Promise((resolve, reject) => {
                predictImage(req, {
                    json: resolve,
                    status: () => ({ json: reject })
                });
            });
        } catch (e) {
            errors.image = e.message || e;
        }
    }
    // Predict audio if present
    if (req.files && req.files.audio) {
        try {
            req.file = req.files.audio[0];
            audioResult = await new Promise((resolve, reject) => {
                predictAudio(req, {
                    json: resolve,
                    status: () => ({ json: reject })
                });
            });
        } catch (e) {
            errors.audio = e.message || e;
        }
    }
    const result = authenticate(imageResult, audioResult);

    // Combine results
    res.json({
        image: imageResult,
        audio: audioResult,
        result,
        errors: Object.keys(errors).length ? errors : undefined
    });
});

app.get('/', (req, res) => {
    res.send('Teachable Machine Multimodal Biometric API');
});

app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
});
