from flask import Flask, jsonify
import random

app = Flask(__name__)

@app.route('/api/data')
def get_data():
    return jsonify({
        "service": "backend",
        "data": {
            "users": random.randint(100, 1000),
            "requests": random.randint(1000, 10000),
            "status": "healthy"
        }
    })

@app.route('/health')
def health():
    return jsonify({"status": "healthy"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)

