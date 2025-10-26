import os
import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image

from config import FACE_EMBEDDINGS, UPLOAD_DIR, ALLOWED_IMAGE_EXTENSIONS


face_transform = transforms.Compose(
    [
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ]
)


def allowed_image(filename: str) -> bool:
    return filename.rsplit(".", 1)[-1].lower() in ALLOWED_IMAGE_EXTENSIONS


def get_device():
    # Prefer MPS on Apple Silicon (M2/M1) if available, otherwise CUDA if available, else CPU
    if (
        getattr(torch.backends, "mps", None) is not None
        and torch.backends.mps.is_available()
    ):
        device = torch.device("mps")
        print(f"[FACE] Using device: MPS (Apple Silicon)")
        return device
    if torch.cuda.is_available():
        device = torch.device("cuda")
        print(f"[FACE] Using device: CUDA (GPU)")
        return device
    device = torch.device("cpu")
    print(f"[FACE] Using device: CPU")
    return device


def load_face_model(model_path: str = FACE_EMBEDDINGS):
    # model architecture must match saved `auth_model.pth`
    print(f"[FACE] Loading face model from: {os.path.basename(model_path)}")
    device = get_device()
    model = models.mobilenet_v2(pretrained=False)
    model.classifier[1] = nn.Linear(model.last_channel, 2)
    state = torch.load(model_path, map_location="cpu")
    model.load_state_dict(state)
    model.to(device)
    model.eval()
    print(f"[FACE] Model loaded successfully")
    return model


def predict_face(image_path: str, model=None):
    """
    Returns: dict {"verified": bool, "person": str, "confidence": float, "similarities": {...}}
    """
    print(f"\n[FACE] Processing image: {os.path.basename(image_path)}")
    if model is None:
        model = load_face_model()

    img = Image.open(image_path).convert("RGB")
    print(f"[FACE] Image loaded: {img.size} pixels")
    x = face_transform(img).unsqueeze(0)
    # move tensor to model device
    device = next(model.parameters()).device
    x = x.to(device)
    print(f"[FACE] Running inference...")
    with torch.no_grad():
        logits = model(x)
        probs = torch.softmax(logits, dim=1)[0].cpu()
    # probs is [p_class0, p_class1]
    # class mapping: 0 -> Diptayan, 1 -> Palash
    conf, pred = torch.max(probs, dim=0)
    # pred==0 => diptayan, pred==1 => palash
    person = "diptayan" if pred.item() == 0 else "palash"

    # Provide similarities as probabilities per known persons
    similarities = {
        "diptayan": float(probs[0].item()),
        "palash": float(probs[1].item()),
    }

    print(f"[FACE] Similarities:")
    for name, score in sorted(similarities.items(), key=lambda x: x[1], reverse=True):
        print(f"   • {name.capitalize()}: {score:.4f}")
    print(f"[FACE] Predicted person: {person.upper()}")
    print(f"[FACE] Confidence: {conf.item():.4f}")

    return {
        "verified": True if conf.item() > 0.0 else False,
        "person": person,
        "confidence": float(conf.item()),
        "similarities": similarities,
    }
