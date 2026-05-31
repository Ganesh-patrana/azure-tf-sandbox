from flask import Flask, jsonify
import os
app = Flask(__name__)

# This simulates a version change that we will trigger later via CI/CD
APP_VERSION = "1.0.0"

@app.route('/')
def home():
    return jsonify({
        "company": "Amadeus",
        "service": "Flight Search Engine",
        "version": APP_VERSION,
        "status": "Healthy",
        "message": "Welcome to the Amadeus Global Distribution System"
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)