# scripts/test_services.py
import requests
import base64
import json
import time


def test_document_intelligence(service_url):
    """Test document intelligence service."""
    print("Testing Document Intelligence Service...")

    test_text = """
    John Smith works at Acme Corporation as a Senior Engineer.
    His email is john.smith@acme.com and his phone number is (555) 123-4567.
    The project started on January 15, 2024.
    """

    payload = {"text": test_text, "entity_types": ["PERSON", "ORG", "EMAIL", "PHONE"]}

    start_time = time.time()
    response = requests.post(f"{service_url}/process", json=payload)
    end_time = time.time()

    print(f"Response Status: {response.status_code}")
    print(f"Response Time: {end_time - start_time:.3f}s")

    if response.status_code == 200:
        result = response.json()
        print(f"Entities Found: {len(result['entities'])}")
        print(f"Processing Time: {result['processing_time']}s")
        print(f"Average Confidence: {result['confidence_score']}")
    else:
        print(f"Error: {response.text}")


def test_computer_vision(service_url):
    """Test computer vision service."""
    print("\nTesting Computer Vision Service...")

    # Create a simple test image (1x1 pixel)
    test_image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

    payload = {"image": test_image, "top_k": 3}

    start_time = time.time()
    response = requests.post(f"{service_url}/classify", json=payload)
    end_time = time.time()

    print(f"Response Status: {response.status_code}")
    print(f"Response Time: {end_time - start_time:.3f}s")

    if response.status_code == 200:
        result = response.json()
        print(f"Predictions: {len(result['predictions'])}")
        print(f"Processing Time: {result['processing_time']}s")
    else:
        print(f"Error: {response.text}")


if __name__ == "__main__":
    # Replace with actual service URLs after deployment
    doc_service_url = "https://document-intelligence-xyz-uc.a.run.app"
    vision_service_url = "https://computer-vision-xyz-uc.a.run.app"

    test_document_intelligence(doc_service_url)
    test_computer_vision(vision_service_url)
