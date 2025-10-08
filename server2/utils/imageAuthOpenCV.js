
const path = require('path');

/**
 * Detects if a person (face) is present in the image using OpenCV.
 * @param {string} imagePath - Path to the image file.
 * @returns {Promise<boolean>} - Resolves true if a face is detected, false otherwise.
 */
async function detectPersonOpenCV(imagePath) {
    const image = await cv.imreadAsync(imagePath);
    const gray = await image.bgrToGrayAsync();
    const classifier = new cv.CascadeClassifier(cv.HAAR_FRONTALFACE_ALT2);
    const faces = await classifier.detectMultiScaleAsync(gray);
    return Array.isArray(faces.objects) && faces.objects.length > 0;
}

/**
 * Loads and detects the largest face in an image, returns the face region as Mat.
 * @param {string} imagePath
 * @returns {Promise<cv.Mat|null>} Cropped face Mat or null if not found
 */
async function getFaceMat(imagePath) {
    const image = await cv.imreadAsync(imagePath);
    const gray = await image.bgrToGrayAsync();
    const classifier = new cv.CascadeClassifier(cv.HAAR_FRONTALFACE_ALT2);
    const faces = await classifier.detectMultiScaleAsync(gray);
    if (!faces.objects || faces.objects.length === 0) return null;
    // Use the largest face
    const faceRects = faces.objects;
    const largest = faceRects.reduce((max, rect) => (rect.width * rect.height > max.width * max.height ? rect : max), faceRects[0]);
    return image.getRegion(largest).resize(150, 150); // Normalize size
}

/**
 * Computes the L2 norm (Euclidean distance) between two face Mats.
 * @param {cv.Mat} mat1
 * @param {cv.Mat} mat2
 * @returns {number}
 */
function faceDistance(mat1, mat2) {
    // Flatten and compare pixel values
    const arr1 = mat1.getDataAsArray().flat(2);
    const arr2 = mat2.getDataAsArray().flat(2);
    if (arr1.length !== arr2.length) return Infinity;
    let sum = 0;
    for (let i = 0; i < arr1.length; i++) {
        sum += Math.pow(arr1[i] - arr2[i], 2);
    }
    return Math.sqrt(sum);
}

/**
 * Recognizes a face in the input image by comparing to known faces.
 * @param {string} inputImagePath - Path to the image to recognize.
 * @param {Array<{name: string, image: string}>} knownFaces - Array of known faces.
 * @param {number} [threshold=5000] - Distance threshold for recognition (tune as needed).
 * @returns {Promise<string|null>} - Name if matched, else null.
 */
async function recognizeFaceOpenCV(inputImagePath, knownFaces, threshold = 5000) {
    const inputFace = await getFaceMat(inputImagePath);
    if (!inputFace) return null;

    let bestMatch = null;
    let bestDist = Infinity;

    for (const face of knownFaces) {
        const knownFaceMat = await getFaceMat(face.image);
        if (!knownFaceMat) continue;
        const dist = faceDistance(inputFace, knownFaceMat);
        if (dist < bestDist) {
            bestDist = dist;
            bestMatch = face.name;
        }
    }
    return bestDist < threshold ? bestMatch : null;
}

module.exports = { detectPersonOpenCV, recognizeFaceOpenCV };
