from flask import Flask, jsonify
import os, datetime

app = Flask(__name__)
BUILD = os.getenv("BUILD_ID", "dev-local")

@app.route("/")
def index():
 return jsonify(
 service="sentra-digital-batam-v2",
 status="running-v4",
 build=BUILD,
 time=datetime.datetime.now().isoformat(timespec="seconds")
 )

@app.route("/health")
def health():
 return jsonify(status="ok"), 500

if __name__ == "__main__":
    app.run(
        host=os.getenv("HOST", "127.0.0.1"),
        port=int(os.getenv("PORT", "5000")),
    )

