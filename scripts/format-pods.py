#!/usr/bin/env python3
"""Format kubectl get pods -A -o json into grouped display."""
import json
import sys

SKIP = set()
if "--app-only" in sys.argv:
    SKIP = {"kube-system", "monitoring", "cert-manager", "ingress-nginx"}

pods = json.load(sys.stdin)["items"]

ns_pods = {}
for p in pods:
    ns = p["metadata"]["namespace"]
    if ns in SKIP:
        continue
    name = p["metadata"]["name"]
    phase = p["status"]["phase"]
    cs = p["status"].get("containerStatuses", [])
    ready = sum(1 for c in cs if c.get("ready"))
    total = len(cs)
    restarts = sum(c.get("restartCount", 0) for c in cs)
    ns_pods.setdefault(ns, []).append((name, phase, ready, total, restarts))

for ns in sorted(ns_pods):
    items = ns_pods[ns]
    all_ok = all(s in ("Running", "Succeeded") for _, s, _, _, _ in items)
    icon = "\033[0;32m●\033[0m" if all_ok else "\033[0;31m●\033[0m"
    print(f"\n{icon} \033[1m{ns}\033[0m ({len(items)} pods)")
    for name, phase, ready, total, restarts in items:
        if phase == "Running":
            st = f"\033[0;32m{phase}\033[0m"
        elif phase == "Succeeded":
            st = f"\033[0;33m{phase}\033[0m"
        else:
            st = f"\033[0;31m{phase}\033[0m"
        r_str = f"  \033[0;33m↻{restarts}\033[0m" if restarts > 0 else ""
        print(f"    {name:<55} {ready}/{total}  {st}{r_str}")
