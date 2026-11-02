from flask import Flask
import socket

app = Flask(__name__)

@app.route("/")
def index():
    return f"Hello from {socket.gethostname()}\n"

@app.route("/health")
def health():
    return "ok", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
