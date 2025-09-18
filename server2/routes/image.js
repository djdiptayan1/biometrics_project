const express = require('express');
const multer = require('multer');
const { predictImage } = require('../controller/imageModel');

const router = express.Router();
const upload = multer({ dest: 'uploads/' });

router.post('/predict', upload.single('image'), predictImage);

module.exports = router;
