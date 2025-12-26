#!/bin/bash
# Load generator script for HPA testing
# This script generates load by making repeated requests to the Flask service

SERVICE_URL="http://flask-service:5000/data"
echo "Generating load on $SERVICE_URL"
echo "Press CTRL+C to stop"

while true; do
  python3 -c "
import urllib.request
import json
try:
    # Make GET request
    urllib.request.urlopen('$SERVICE_URL', timeout=1)
except:
    pass
" 2>/dev/null
done

