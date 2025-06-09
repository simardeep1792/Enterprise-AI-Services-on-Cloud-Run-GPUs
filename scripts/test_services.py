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


if __name__ == "__main__":
    # Replace with actual service URLs after deployment
    doc_service_url = "https://document-intelligence-xyz-uc.a.run.app"

    test_document_intelligence(doc_service_url)
    test_computer_vision(vision_service_url)
