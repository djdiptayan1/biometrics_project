const tf = require('@tensorflow/tfjs-node');
const fs = require('fs');
const path = require('path');

const MODEL_PATH = path.join(__dirname, '../models/ImageModel/model.json');
const METADATA_PATH = path.join(__dirname, '../models/ImageModel/metadata.json');
let model = null;
let labels = [];


async function loadModel() {
    if (!model) {
        console.log('[ImageModel] Step 1: Loading model from', MODEL_PATH);
        model = await tf.loadLayersModel('file://' + MODEL_PATH);
        console.log('[ImageModel] Step 2: Loading metadata from', METADATA_PATH);
        const metadata = JSON.parse(fs.readFileSync(METADATA_PATH, 'utf8'));
        labels = metadata.labels || metadata.wordLabels || [];
        console.log('[ImageModel] Step 3: Model loaded. Classes:', labels);
    }
}

exports.predictImage = async (req, res) => {
    try {
        await loadModel();
        const imagePath = req.file.path;
        console.log('[ImageModel] Step 4: Received image file:', imagePath);
        const imageBuffer = fs.readFileSync(imagePath);
        console.log('[ImageModel] Step 5: Decoding image buffer...');
        const imageTensor = tf.node.decodeImage(imageBuffer, 3);
        console.log('[ImageModel] Step 6: Resizing image to 224x224...');
        const resizedTensor = imageTensor.resizeBilinear([224, 224]);
        console.log('[ImageModel] Step 7: Expanding dimensions and normalizing...');
        const inputTensor = resizedTensor.expandDims(0).toFloat().div(tf.scalar(255));
        console.log('[ImageModel] Step 8: Image preprocessed. Shape:', inputTensor.shape);

        console.log('[ImageModel] Step 9: Running prediction...');
        const prediction = model.predict(inputTensor);
        const probabilities = prediction.dataSync();
        const results = labels.map((label, i) => ({
            className: label,
            probability: probabilities[i]
        }));
        results.sort((a, b) => b.probability - a.probability);
        console.log('[ImageModel] Step 10: Prediction results:', results);

        fs.unlinkSync(imagePath);
        tf.dispose([imageTensor, resizedTensor, inputTensor, prediction]);
        console.log('[ImageModel] Step 11: Cleaned up temporary files and tensors.');

        res.json({ results });
    } catch (err) {
        console.error('[ImageModel] Error:', err);
        res.status(500).json({ error: err.message });
    }
};
