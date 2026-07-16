#!/usr/bin/env python3
import subprocess
import json
import re
import time
import threading
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler

# Global cache
metrics_cache = ""
cache_lock = threading.Lock()

def parse_size(size_str):
    size_str = size_str.strip()
    match = re.match(r'^([\d\.]+)\s*([a-zA-Z]*)$', size_str)
    if not match:
        return 0
    val, unit = match.groups()
    val = float(val)
    unit = unit.lower()
    if 'g' in unit:
        return int(val * 1024 * 1024 * 1024)
    elif 'm' in unit:
        return int(val * 1024 * 1024)
    elif 'k' in unit:
        return int(val * 1024)
    else:
        return int(val)

def collect_metrics():
    global metrics_cache
    while True:
        metrics = []
        servers = []
        try:
            servers_out = subprocess.check_output(["barman", "list-servers"]).decode("utf-8")
            for line in servers_out.strip().split("\n"):
                if not line.strip():
                    continue
                parts = line.split(" - ", 1)
                if parts:
                    servers.append(parts[0].strip())
        except Exception as e:
            metrics.append(f'# Error listing servers: {str(e)}')

        for server in servers:
            # 1. Scrape barman check
            try:
                check_out = subprocess.check_output(["barman", "check", server]).decode("utf-8")
                server_ok = 1
                for line in check_out.split("\n"):
                    # Check lines must be indented
                    if not (line.startswith("\t") or line.startswith("   ") or line.startswith("  ")):
                        continue
                    if ":" in line:
                        metric_name, status = line.split(":", 1)
                        metric_name = re.sub(r'[^a-zA-Z0-9_]', '_', metric_name.strip().lower())
                        metric_name = re.sub(r'_+', '_', metric_name)
                        # Remove leading or trailing underscores
                        metric_name = metric_name.strip('_')
                        status = status.strip()
                        val = 1 if status.startswith("OK") else 0
                        if val == 0:
                            server_ok = 0
                        metrics.append(f'barman_check_{metric_name}{{server="{server}"}} {val}')
                metrics.append(f'barman_up{{server="{server}"}} {server_ok}')
            except Exception as e:
                metrics.append(f'barman_up{{server="{server}"}} 0')
                metrics.append(f'# Error checking server {server}: {str(e)}')

            # 2. Scrape barman backups
            try:
                backups_out = subprocess.check_output(["barman", "list-backups", server]).decode("utf-8")
                backup_lines = [l.strip() for l in backups_out.strip().split("\n") if l.strip()]
                valid_backups = []
                for line in backup_lines:
                    if line.startswith(server) and " - " in line:
                        valid_backups.append(line)
                
                metrics.append(f'barman_backups_total{{server="{server}"}} {len(valid_backups)}')
                
                if valid_backups:
                    latest_ts = 0
                    latest_size = 0
                    latest_wal_size = 0
                    
                    for line in valid_backups:
                        parts = line.split(" - ")
                        subparts = parts[0].split()
                        if len(subparts) < 2:
                            continue
                        backup_id = subparts[1].strip()
                        
                        size_val = 0
                        wal_size_val = 0
                        for part in parts:
                            if part.startswith("Size:"):
                                size_val = parse_size(part.replace("Size:", ""))
                            elif part.startswith("WAL Size:"):
                                wal_size_val = parse_size(part.replace("WAL Size:", ""))
                        
                        try:
                            dt = datetime.strptime(backup_id, "%Y%m%dT%H%M%S")
                            ts = dt.timestamp()
                            if ts > latest_ts:
                                latest_ts = ts
                                latest_size = size_val
                                latest_wal_size = wal_size_val
                        except Exception:
                            pass
                    
                    if latest_ts > 0:
                        age = time.time() - latest_ts
                        metrics.append(f'barman_last_backup_seconds_ago{{server="{server}"}} {int(age)}')
                        metrics.append(f'barman_last_backup_size_bytes{{server="{server}"}} {latest_size}')
                        metrics.append(f'barman_last_backup_wal_size_bytes{{server="{server}"}} {latest_wal_size}')
            except Exception as e:
                metrics.append(f'# Error listing backups for {server}: {str(e)}')
        
        new_cache = "\n".join(metrics) + "\n"
        with cache_lock:
            metrics_cache = new_cache
        
        time.sleep(10)

class BarmanExporter(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; version=0.0.4')
            self.end_headers()
            with cache_lock:
                self.wfile.write(metrics_cache.encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

def run(server_class=HTTPServer, handler_class=BarmanExporter, port=9780):
    t = threading.Thread(target=collect_metrics, daemon=True)
    t.start()
    
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print(f"Starting Barman Exporter on port {port}...")
    httpd.serve_forever()

if __name__ == '__main__':
    run()
