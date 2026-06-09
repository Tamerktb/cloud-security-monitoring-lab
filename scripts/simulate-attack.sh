#!/bin/bash
# Simulates various attack scenarios to test detection rules
set -e

TARGET_IP="$1"

if [ -z "$TARGET_IP" ]; then
  echo "Usage: $0 <TARGET_IP>"
  echo ""
  echo "Examples:"
  echo "  Simulate SSH brute force:"
  echo "    $0 10.0.1.100"
  echo ""
  echo "  Simulate port scan:"
  echo "    TARGET=10.0.1.100 bash $0"
  exit 1
fi

echo "=== Attack Simulation Menu ==="
echo "1) SSH Brute Force (hydra)"
echo "2) Port Scan (nmap)"
echo "3) S3 Bucket Enumeration"
echo "4) All of the above"
echo ""

read -rp "Select scenario [1-4]: " choice

case $choice in
  1)
    echo "=== Running SSH brute force ==="
    hydra -l ubuntu -P /usr/share/wordlists/rockyou.txt "$TARGET_IP" ssh -t 4 -f
    ;;
  2)
    echo "=== Running port scan ==="
    nmap -sS -sV -p- "$TARGET_IP" -T4
    ;;
  3)
    echo "=== Running S3 bucket enumeration ==="
    aws s3 ls s3://example-secops-lab-cloudtrail-logs/ --no-sign-request 2>/dev/null || \
      echo "Bucket not public. Attempting brute-force..."
    for name in logs data backup test; do
      aws s3 ls "s3://${name}-${TARGET_IP}/" --no-sign-request 2>/dev/null && \
        echo "[!] Found public bucket: ${name}-${TARGET_IP}"
    done
    ;;
  4)
    echo "=== Running all attack scenarios ==="
    echo "--- Port scan ---"
    nmap -sS -sV "$TARGET_IP" -T4
    echo "--- SSH brute force ---"
    hydra -l ubuntu -P /usr/share/wordlists/rockyou.txt "$TARGET_IP" ssh -t 4 -f 2>/dev/null || true
    echo "--- S3 enumeration ---"
    for name in logs data backup test; do
      aws s3 ls "s3://${name}-test/" --no-sign-request 2>/dev/null && \
        echo "[!] Found public bucket: ${name}-test"
    done
    echo "=== All scenarios complete ==="
    ;;
  *)
    echo "Invalid choice"
    exit 1
    ;;
esac
