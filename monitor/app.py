import os
import time
import threading
import requests
from datetime import datetime, timezone
from flask import Flask, render_template, jsonify
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

app = Flask(__name__)

# ---------------------------------------------------------------------------
# Cluster endpoints from environment
# ---------------------------------------------------------------------------
CLUSTERS = {}
for key, val in os.environ.items():
    if key.startswith("CLUSTER_") and key.endswith("_URL"):
        name_part = key.replace("CLUSTER_", "").replace("_URL", "")
        name = name_part.lower().replace("_", "-")
        env_key = f"CLUSTER_{name_part}_ENV"
        CLUSTERS[name] = {
            "url": val,
            "env": os.environ.get(env_key, "unknown"),
            "name": name,
        }

CHECK_INTERVAL = int(os.environ.get("CHECK_INTERVAL", "5"))
MAX_HISTORY = 360

health_data = {}
lock = threading.Lock()

# ---------------------------------------------------------------------------
# Dedicated HTTP sessions — one per purpose to avoid head-of-line blocking.
# Short keep-alive to avoid stale Azure LB connections.
# ---------------------------------------------------------------------------
def _make_session():
    s = requests.Session()
    adapter = HTTPAdapter(
        pool_connections=10,
        pool_maxsize=10,
        max_retries=Retry(total=0),  # no retries — we want raw latency
    )
    s.mount("http://", adapter)
    s.mount("https://", adapter)
    # Disable keep-alive to avoid stale-connection spikes through Azure LB
    s.headers.update({"Connection": "close"})
    return s

_health_session = _make_session()
_info_session = _make_session()


def init_cluster_data(name):
    return {
        "name": name,
        "url": CLUSTERS[name]["url"],
        "env": CLUSTERS[name]["env"],
        "status": "unknown",
        "latency_ms": 0,
        "latency_avg": 0,
        "last_check": None,
        "uptime_pct": 100.0,
        "checks_total": 0,
        "checks_ok": 0,
        "checks_fail": 0,
        "history": [],
        "k8s_version": "unknown",
        "node_name": "unknown",
        "pod_name": "unknown",
        "current_response": {},
    }


def _rolling_avg(history, window=12):
    """Return rolling average of the last `window` successful latency samples."""
    recent = [h["latency_ms"] for h in history[-window:] if h["status"] == "up"]
    return round(sum(recent) / len(recent)) if recent else 0


def check_cluster(name, info):
    """
    Health-check a single cluster.

    Latency measurement:
      - Timed ONLY on the lightweight /api/health endpoint.
      - Uses Connection: close to guarantee a fresh TCP socket each check,
        eliminating stale-connection spikes through the Azure Load Balancer.

    Metadata (/api/info):
      - Fetched separately AFTER the latency measurement.
      - Does NOT affect the reported latency number.
    """
    # ── 1. Latency probe: /api/health only ──────────────────────────────
    start = time.monotonic()
    status = "down"
    latency = 0

    try:
        resp = _health_session.get(
            f"{info['url']}/api/health",
            timeout=(2, 3),
        )
        latency = round((time.monotonic() - start) * 1000)
        status = "up" if resp.status_code == 200 else "down"
    except requests.exceptions.ConnectionError:
        latency = round((time.monotonic() - start) * 1000)
    except requests.exceptions.Timeout:
        latency = round((time.monotonic() - start) * 1000)
    except Exception:
        latency = round((time.monotonic() - start) * 1000)

    # ── 2. Metadata fetch (best-effort, non-blocking to latency) ────────
    cluster_info = {}
    if status == "up":
        try:
            info_resp = _info_session.get(
                f"{info['url']}/api/info",
                timeout=(2, 3),
            )
            if info_resp.status_code == 200:
                cluster_info = info_resp.json()
        except Exception:
            pass

    # ── 3. Record results ───────────────────────────────────────────────
    now = datetime.now(timezone.utc).isoformat()

    with lock:
        d = health_data[name]
        d["status"] = status
        d["latency_ms"] = latency
        d["last_check"] = now
        d["checks_total"] += 1
        if status == "up":
            d["checks_ok"] += 1
            if cluster_info:
                d["k8s_version"] = cluster_info.get("k8s_version", d["k8s_version"])
                d["node_name"] = cluster_info.get("node_name", d["node_name"])
                d["pod_name"] = cluster_info.get("pod_name", d["pod_name"])
                d["current_response"] = cluster_info
        else:
            d["checks_fail"] += 1

        d["uptime_pct"] = round(
            d["checks_ok"] / d["checks_total"] * 100, 2
        ) if d["checks_total"] > 0 else 0

        d["history"].append({
            "ts": now,
            "status": status,
            "latency_ms": latency,
        })
        if len(d["history"]) > MAX_HISTORY:
            d["history"] = d["history"][-MAX_HISTORY:]

        d["latency_avg"] = _rolling_avg(d["history"])


def monitor_loop():
    while True:
        threads = []
        for name, info in CLUSTERS.items():
            t = threading.Thread(target=check_cluster, args=(name, info))
            t.start()
            threads.append(t)
        for t in threads:
            t.join()
        time.sleep(CHECK_INTERVAL)


# ---------------------------------------------------------------------------
# Initialise and start background monitor
# ---------------------------------------------------------------------------
for name in CLUSTERS:
    health_data[name] = init_cluster_data(name)

monitor_thread = threading.Thread(target=monitor_loop, daemon=True)
monitor_thread.start()


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
@app.route("/")
def index():
    return render_template("index.html", clusters=CLUSTERS, check_interval=CHECK_INTERVAL)


@app.route("/api/status")
def api_status():
    with lock:
        return jsonify(health_data)


@app.route("/api/reset")
def api_reset():
    with lock:
        for name in health_data:
            health_data[name] = init_cluster_data(name)
    return jsonify({"status": "reset"})


@app.route("/api/health")
def health():
    return jsonify({"status": "healthy"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8090)
