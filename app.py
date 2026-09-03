import os
import time
from flask import Flask, jsonify

app = Flask(__name__)

# Basic landing page matching Phase 3
@app.route('/', methods=['GET'])
def index():
    return "ChaosOps application running"

# Health probe endpoint for Kubernetes liveness/readiness probes
@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"})

# Version tracking endpoint
@app.route('/version', methods=['GET'])
def version():
    return jsonify({"version": "1.0.0"})

# CPU stress simulation endpoint to test scaling/monitoring metrics
@app.route('/cpu', methods=['GET'])
def cpu_stress():
    start_time = time.time()
    # Performs a controlled CPU workload for roughly 1 second
    while time.time() - start_time < 1.0:
        _ = 12345 * 67890
    return jsonify({"message": "controlled CPU workload completed"})

if __name__ == '__main__':
    # Binds to 0.0.0.0 to allow containerized network access
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
