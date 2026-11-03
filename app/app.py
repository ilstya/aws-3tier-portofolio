import json
import os
import socket

import boto3
import pymysql
from flask import Flask

app = Flask(__name__)


def get_conn():
    sm = boto3.client("secretsmanager")
    secret = json.loads(
        sm.get_secret_value(SecretId=os.environ["DB_SECRET_ARN"])["SecretString"]
    )
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        user=secret["username"],
        password=secret["password"],
        database="appdb",
        connect_timeout=5,
    )


@app.route("/")
def index():
    return f"Hello from {socket.gethostname()}\n"


@app.route("/health")
def health():
    return "ok", 200


@app.route("/db")
def db():
    try:
        conn = get_conn()
        with conn.cursor() as cur:
            cur.execute("SELECT VERSION()")
            version = cur.fetchone()[0]
        conn.close()
        return f"DB connected, MySQL {version}\n"
    except Exception as e:
        return f"DB error: {type(e).__name__}\n", 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
