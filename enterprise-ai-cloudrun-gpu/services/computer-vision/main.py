import os
import logging
import time
import base64
import io
from typing import Dict, List
from dataclasses import dataclass, asdict

from flask import Flask, request, jsonify
from google.cloud import monitoring_v3
from google.cloud import logging as cloud_logging
import torch
import torchvision.transforms as transforms
from torchvision import models
from PIL import Image

cloud_logging.Client().setup_logging()
logger = logging.getLogger(__name__)


@dataclass
class ClassificationResult:
    success: bool
    processing_time: float
    predictions: List[Dict]
    error_message: str = None


class ImageClassifier:
    def __init__(self):
        self.project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
        self.service_name = os.getenv("K_SERVICE", "computer-vision")

        self.monitoring_client = monitoring_v3.MetricServiceClient()
        self._initialize_model()

        logger.info(
            f"Vision service initialized - GPU Available: {torch.cuda.is_available()}"
        )

    def _initialize_model(self):
        try:
            # Load pre-trained ResNet50
            self.model = models.resnet50(pretrained=True)
            self.model.eval()

            if torch.cuda.is_available():
                self.model = self.model.cuda()

            # Define preprocessing pipeline
            self.preprocess = transforms.Compose(
                [
                    transforms.Resize(256),
                    transforms.CenterCrop(224),
                    transforms.ToTensor(),
                    transforms.Normalize(
                        mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]
                    ),
                ]
            )

            # Load ImageNet class labels
            self.class_labels = self._load_imagenet_labels()

            logger.info("Vision model loaded successfully")

        except Exception as e:
            logger.error(f"Failed to initialize vision model: {str(e)}")
            raise

    def _load_imagenet_labels(self):
        # Simplified label mapping - in production, load from file
        return {i: f"class_{i}" for i in range(1000)}

    def _record_metrics(self, processing_time: float, success: bool):
        try:
            series = monitoring_v3.TimeSeries()
            series.metric.type = "custom.googleapis.com/vision_service/processing_time"
            series.resource.type = "cloud_run_revision"
            series.resource.labels["project_id"] = self.project_id
            series.resource.labels["service_name"] = self.service_name
            series.metric.labels["success"] = str(success)

            now = time.time()
            seconds = int(now)
            nanos = int((now - seconds) * 10**9)
            interval = monitoring_v3.TimeInterval(
                {"end_time": {"seconds": seconds, "nanos": nanos}}
            )
            point = monitoring_v3.Point(
                {"interval": interval, "value": {"double_value": processing_time}}
            )
            series.points = [point]

            project_name = f"projects/{self.project_id}"
            self.monitoring_client.create_time_series(
                name=project_name, time_series=[series]
            )

        except Exception as e:
            logger.warning(f"Failed to record metrics: {str(e)}")

    def classify_image(self, image_base64: str, top_k: int = 5) -> ClassificationResult:
        start_time = time.time()

        try:
            # Decode base64 image
            image_data = base64.b64decode(image_base64)
            image = Image.open(io.BytesIO(image_data)).convert("RGB")

            # Preprocess image
            input_tensor = self.preprocess(image)
            input_batch = input_tensor.unsqueeze(0)

            if torch.cuda.is_available():
                input_batch = input_batch.cuda()

            # Run inference
            with torch.no_grad():
                output = self.model(input_batch)

            # Get top predictions
            probabilities = torch.nn.functional.softmax(output[0], dim=0)
            top_prob, top_indices = torch.topk(probabilities, top_k)

            predictions = []
            for i in range(top_k):
                predictions.append(
                    {
                        "class_id": top_indices[i].item(),
                        "class_name": self.class_labels.get(
                            top_indices[i].item(), "unknown"
                        ),
                        "confidence": round(top_prob[i].item(), 4),
                    }
                )

            processing_time = time.time() - start_time
            self._record_metrics(processing_time, True)

            logger.info(f"Image classified: {processing_time:.3f}s")

            return ClassificationResult(
                success=True,
                processing_time=round(processing_time, 4),
                predictions=predictions,
            )

        except Exception as e:
            processing_time = time.time() - start_time
            self._record_metrics(processing_time, False)

            logger.error(f"Image classification failed: {str(e)}")

            return ClassificationResult(
                success=False,
                processing_time=round(processing_time, 4),
                predictions=[],
                error_message=str(e),
            )


app = Flask(__name__)
classifier = ImageClassifier()


@app.route("/health", methods=["GET"])
def health_check():
    return jsonify(
        {
            "status": "healthy",
            "service": "computer-vision",
            "gpu_available": torch.cuda.is_available(),
            "timestamp": time.time(),
        }
    )


@app.route("/classify", methods=["POST"])
def classify_image():
    try:
        data = request.get_json()

        if not data or "image" not in data:
            return jsonify({"error": "Missing required field: image"}), 400

        image_base64 = data["image"]
        top_k = data.get("top_k", 5)

        if top_k < 1 or top_k > 10:
            return jsonify({"error": "top_k must be between 1 and 10"}), 400

        result = classifier.classify_image(image_base64, top_k)

        return jsonify(asdict(result)), 200 if result.success else 400

    except Exception as e:
        logger.error(f"Request processing failed: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)
