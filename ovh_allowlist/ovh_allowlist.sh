#!/bin/bash

# OVH IP Allowlist Update Script
# Updates existing network access entry with current public IP

# Load .env file if it exists
if [ -f ".env" ]; then
    echo "Loading environment variables from .env file..."
    set -a  # automatically export all variables
    source .env
    set +a  # disable automatic export
fi

# Check if required environment variables are set
if [ -z "$OVH_APPLICATION_KEY" ] || [ -z "$OVH_APPLICATION_SECRET" ] || [ -z "$OVH_CONSUMER_KEY" ] || [ -z "$SERVICE_NAME" ] || [ -z "$NETWORK_ACCESS_ID" ] || [ -z "$DESCRIPTION" ]; then
    echo "Error: Required environment variables not set!"
    echo "Please set the following environment variables or create a .env file:"
    echo "  export OVH_APPLICATION_KEY='your_application_key'"
    echo "  export OVH_APPLICATION_SECRET='your_application_secret'"
    echo "  export OVH_CONSUMER_KEY='your_consumer_key'"
    echo "  export SERVICE_NAME='pcc-xxx-xx-xx-xx'"
    echo "  export NETWORK_ACCESS_ID='1234'"
    echo "  export DESCRIPTION='Your Public IP'"
    echo ""
    echo "Or copy .env.example to .env and edit the values:"
    echo "  cp .env.example .env"
    echo "  vim .env"
    exit 1
fi

# Get current public IP
echo "Getting current public IP..."
CURRENT_IP=$(curl -s https://ipinfo.io/ip)

if [ -z "$CURRENT_IP" ]; then
    echo "Error: Could not retrieve current public IP"
    exit 1
fi

echo "Current public IP: $CURRENT_IP"

# Prepare request body
REQUEST_BODY=$(cat <<EOF
{
  "description": "$DESCRIPTION",
  "network": "$CURRENT_IP/32"
}
EOF
)

# Generate timestamp and signature for OVH API
TIMESTAMP=$(date +%s)
METHOD="PUT"
QUERY=""
BODY="$REQUEST_BODY"
URL="/dedicatedCloud/$SERVICE_NAME/allowedNetwork/$NETWORK_ACCESS_ID"

# Create signature
TO_SIGN="$OVH_APPLICATION_SECRET+$OVH_CONSUMER_KEY+$METHOD+https://eu.api.ovh.com/1.0$URL+$BODY+$TIMESTAMP"
SIGNATURE='$1$'$(echo -n "$TO_SIGN" | sha1sum | cut -d' ' -f1)

echo "Updating OVH allowlist entry..."

# Make API call
RESPONSE=$(curl -s -X PUT \
    -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
    -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY" \
    -H "X-Ovh-Signature: $SIGNATURE" \
    -H "X-Ovh-Timestamp: $TIMESTAMP" \
    -H "Content-Type: application/json" \
    -d "$REQUEST_BODY" \
    "https://eu.api.ovh.com/1.0$URL")

# Check response
if echo "$RESPONSE" | grep -q "error"; then
    echo "Error updating allowlist:"
    echo "$RESPONSE"
    exit 1
else
    echo "Success! IP allowlist updated."
    echo "New network: $CURRENT_IP/32"
    echo "Response: $RESPONSE"
fi