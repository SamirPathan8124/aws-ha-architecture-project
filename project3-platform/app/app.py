from flask import Flask, jsonify
import os, socket

app = Flask(__name__)

@app.route("/")
def home():
    return jsonify(message="Secure Multi-Region DevOps Platform",
                   region=os.getenv("AWS_REGION", "local"),
                   host=socket.gethostname())

@app.route("/health")
def health():
    return jsonify(status="ok"), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
