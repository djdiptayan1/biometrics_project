
function authenticate(imageResult, audioResult) {
    // If results are missing or not arrays, treat as not detected
    if (!imageResult || !Array.isArray(imageResult.results) || imageResult.results.length === 0 ||
        !audioResult || !Array.isArray(audioResult.results) || audioResult.results.length === 0) {
        return { authenticated: false, name: null };
    }

    const minImageProb = 0.7;
    const minAudioProb = 0.3;

    const imgTop = imageResult.results[0];
    // For audio, skip 'Background Noise' if present, else take top
    let audTop = audioResult.results[0];
    if (audTop.className === 'Background Noise' && audioResult.results.length > 1) {
        audTop = audioResult.results[1];
    }

    // If either is missing or null, not authenticated
    if (!imgTop || !audTop || !imgTop.className || !audTop.className || imgTop.className === null || audTop.className === null) {
        return { authenticated: false, name: null };
    }

    const samePerson =
        imgTop.className === audTop.className &&
        imgTop.probability >= minImageProb &&
        audTop.probability >= minAudioProb;

    return {
        authenticated: samePerson,
        name: samePerson ? imgTop.className : null
    };
}

module.exports = { authenticate };
