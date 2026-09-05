import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import pytest
from app.app import app  # Import from the app/app.py module

@pytest.fixture
def client():
    """Sets up a temporary testing browser client."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_root(client):
    response = client.get('/')
    assert response.status_code == 200
    assert response.data.decode('utf-8') == "ChaosOps application running"

def test_health(client):
    response = client.get('/health')
    assert response.status_code == 200
    assert response.get_json() == {"status": "healthy"}

def test_version(client):
    response = client.get('/version')
    assert response.status_code == 200
    assert response.get_json() == {"version": "1.0.0"}

