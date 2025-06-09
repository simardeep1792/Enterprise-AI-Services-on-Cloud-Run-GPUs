import os
import logging
import time
import json
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict

from flask import Flask, request, jsonify
from google.cloud import monitoring_v3
from google.cloud import logging as cloud_logging
import torch
from transformers import pipeline, AutoTokenizer, AutoModelForTokenClassification

# Configure logging
cloud_logging.Client().setup_logging()
logger = logging.getLogger(__name__)


@dataclass
class ProcessingResult:
    success: bool
    processing_time: float
    entities: List[Dict]
    confidence_score: float
    error_message: Optional[str] = None


class DocumentProcessor:
    def __init__(self):
        self.project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
        self.service_name = os.getenv("K_SERVICE", "document-intelligence")

        # Initialize monitoring
        self.monitoring_client = monitoring_v3.MetricServiceClient()

        # Load model
        self._initialize_model()

        logger.info(f"Service initialized - GPU Available: {torch.cuda.is_available()}")

    def _initialize_model(self):
        try:
            model_name = "dbmdz/bert-large-cased-finetuned-conll03-english"
            self.tokenizer = AutoTokenizer.from_pretrained(model_name)

            device = "cuda" if torch.cuda.is_available() else "cpu"
            self.model = AutoModelForTokenClassification.from_pretrained(model_name)
            self.model.to(device)

            self.ner_pipeline = pipeline(
                "ner",
                model=self.model,
                tokenizer=self.tokenizer,
                device=0 if torch.cuda.is_available() else -1,
                aggregation_strategy="simple",
            )

            logger.info(f"Model loaded successfully on {device}")

        except Exception as e:
            logger.error(f"Failed to initialize model: {str(e)}")
            raise

    def _record_metrics(self, processing_time: float, entity_count: int, success: bool):
        try:
            # Record processing time metric
            series = monitoring_v3.TimeSeries()
            series.metric.type = "custom.googleapis.com/ai_service/processing_time"
            series.resource.type = "cloud_run_revision"
            series.resource.labels["project_id"] = self.project_id
            series.resource.labels["service_name"] = self.service_name

            series.metric.labels["success"] = str(success)
            series.metric.labels["entity_count"] = str(entity_count)

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

    def process_document(
        self, text: str, entity_types: List[str] = None
    ) -> ProcessingResult:
        start_time = time.time()

        try:
            # Input validation
            if not text or len(text.strip()) == 0:
                raise ValueError("Document text cannot be empty")

            if len(text) > 100000:
                raise ValueError("Document exceeds maximum length")

            # Process with NER
            entities = self.ner_pipeline(text)

            # Filter and format results
            filtered_entities = []
            confidence_scores = []

            for entity in entities:
                if not entity_types or entity["entity_group"] in entity_types:
                    filtered_entities.append(
                        {
                            "text": entity["word"],
                            "label": entity["entity_group"],
                            "start": entity["start"],
                            "end": entity["end"],
                            "confidence": round(entity["score"], 4),
                        }
                    )
                    confidence_scores.append(entity["score"])

            processing_time = time.time() - start_time
            avg_confidence = (
                sum(confidence_scores) / len(confidence_scores)
                if confidence_scores
                else 0.0
            )

            # Record metrics
            self._record_metrics(processing_time, len(filtered_entities), True)

            logger.info(
                f"Document processed: {len(filtered_entities)} entities, {processing_time:.3f}s"
            )

            return ProcessingResult(
                success=True,
                processing_time=round(processing_time, 4),
                entities=filtered_entities,
                confidence_score=round(avg_confidence, 4),
            )

        except Exception as e:
            processing_time = time.time() - start_time
            self._record_metrics(processing_time, 0, False)

            logger.error(f"Document processing failed: {str(e)}")

            return ProcessingResult(
                success=False,
                processing_time=round(processing_time, 4),
                entities=[],
                confidence_score=0.0,
                error_message=str(e),
            )


# Initialize Flask app
app = Flask(__name__)
processor = DocumentProcessor()


@app.route("/health", methods=["GET"])
def health_check():
    return jsonify(
        {
            "status": "healthy",
            "service": "document-intelligence",
            "gpu_available": torch.cuda.is_available(),
            "timestamp": time.time(),
        }
    )


@app.route("/process", methods=["POST"])
def process_document():
    try:
        data = request.get_json()

        if not data or "text" not in data:
            return jsonify({"error": "Missing required field: text"}), 400

        text = data["text"]
        entity_types = data.get("entity_types", None)

        result = processor.process_document(text, entity_types)

        return jsonify(asdict(result)), 200 if result.success else 400

    except Exception as e:
        logger.error(f"Request processing failed: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)
