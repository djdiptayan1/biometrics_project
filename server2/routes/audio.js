const express = require('express');
const multer = require('multer');
const { predictAudio } = require('../controller/audioModel');

const router = express.Router();
const upload = multer({ dest: 'uploads/' });

router.post('/predict', upload.single('audio'), predictAudio);

module.exports = router;
