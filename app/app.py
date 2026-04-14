import os
import socket
import subprocess
from datetime import datetime
from flask import Flask, render_template, jsonify

app = Flask(__name__)

# Auto-detect K8s version from the node
def get_k8s_version():
    """Get K8s version from the Kubernetes API via service account"""
    try:
        token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"
        ca_path = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
        if os.path.exists(token_path):
            import urllib.request, ssl, json
            token = open(token_path).read()
            ctx = ssl.create_default_context(cafile=ca_path)
            req = urllib.request.Request(
                "https://kubernetes.default.svc/version",
                headers={"Authorization": f"Bearer {token}"}
            )
            resp = urllib.request.urlopen(req, context=ctx, timeout=2)
            data = json.loads(resp.read())
            return f"{data.get('major','')}.{data.get('minor','').rstrip('+')}"
    except Exception:
        pass
    return os.environ.get("K8S_VERSION", "unknown")

# Cache the version (doesn't change during pod lifetime)
_k8s_version = None

def get_cached_k8s_version():
    global _k8s_version
    if _k8s_version is None:
        _k8s_version = get_k8s_version()
    return _k8s_version

def get_cluster_info():
    return {
        "cluster_name": os.environ.get("CLUSTER_NAME", "unknown"),
        "environment": os.environ.get("ENVIRONMENT", "unknown"),
        "region": os.environ.get("REGION", "unknown"),
        "node_name": os.environ.get("NODE_NAME", socket.gethostname()),
        "pod_name": os.environ.get("POD_NAME", socket.gethostname()),
        "pod_ip": os.environ.get("POD_IP", "unknown"),
        "namespace": os.environ.get("POD_NAMESPACE", "default"),
        "app_version": os.environ.get("APP_VERSION", "1.0.0"),
        "k8s_version": get_cached_k8s_version(),
        "timestamp": datetime.utcnow().isoformat() + "Z",
    }

@app.route("/")
def index():
    info = get_cluster_info()
    return render_template("index.html", info=info)

@app.route("/api/info")
def api_info():
    return jsonify(get_cluster_info())

@app.route("/api/health")
def health():
    return jsonify({"status": "healthy", "timestamp": datetime.utcnow().isoformat() + "Z"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
