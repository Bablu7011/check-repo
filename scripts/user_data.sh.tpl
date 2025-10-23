#!/bin/bash
set -e

# Make apt-get non-interactive
export DEBIAN_FRONTEND=noninteractive

echo "Starting user_data script..."

# --------------------------
# System update & required tools
# --------------------------
echo "Running apt-get update..."
apt-get update -y
echo "Running apt-get install..."
apt-get install -y openjdk-21-jdk awscli python3
echo "Finished apt-get install."

# --------------------------
# Create application directory
# --------------------------
echo "Creating /app directory..."
mkdir -p /app/
cd /app/
echo "Changed to /app directory."

# --------------------------
# Create the polling script
# --------------------------
echo "Creating /app/poll_s3.sh script..."
cat << 'EOF' > /app/poll_s3.sh
#!/bin/bash
set -e

# Variables passed from Terraform
JAR_BUCKET="${JAR_BUCKET}"
EC2_LOGS_BUCKET="${EC2_LOGS_BUCKET}"
APP_DIR="/app"
ARTIFACT_DIR="$${APP_DIR}/artifacts"
CURRENT_JAR_MD5=""

# Get the unique instance ID from instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

echo "Polling service started for bucket: s3://$${JAR_BUCKET}"

# Ensure artifacts directory exists
mkdir -p $${ARTIFACT_DIR}

while true; do
  # --- APP DEPLOYMENT LOGIC ---
  echo "Syncing JARs from S3..."
  aws s3 sync s3://$${JAR_BUCKET} $${ARTIFACT_DIR} --delete
  JAR_FILE=$(find $${ARTIFACT_DIR} -maxdepth 1 -name "*.jar" | head -n 1)

  if [ -f "$${JAR_FILE}" ]; then
    NEW_JAR_MD5=$(md5sum "$${JAR_FILE}" | awk '{ print $1 }')

    if [ "$${NEW_JAR_MD5}" != "$${CURRENT_JAR_MD5}" ]; then
      echo "New JAR file detected. Restarting application..."
      CURRENT_JAR_MD5=$${NEW_JAR_MD5}

      if pgrep -f "java -jar" || pgrep -f "python3 -m http.server 80"; then
        pkill -f "java -jar" || true
        pkill -f "python3 -m http.server 80" || true
        echo "Killed old process on port 80."
        sleep 5
      fi

      echo "Starting new application from $${JAR_FILE}..."
      nohup java -jar "$${JAR_FILE}" --server.port=80 > /app/app.log 2>&1 &
      echo "Started new application from $${JAR_FILE}."
    fi
  else
    echo "No JAR file found in S3 bucket."
  fi

  # --- LOG UPLOAD LOGIC ---
  if [ -f "/app/app.log" ]; then
    aws s3 cp /app/app.log s3://$${EC2_LOGS_BUCKET}/$${INSTANCE_ID}/app.log || true
  fi
  if [ -f "/app/polling_service.log" ]; then
    aws s3 cp /app/polling_service.log s3://$${EC2_LOGS_BUCKET}/$${INSTANCE_ID}/polling_service.log || true
  fi
  
  sleep 300
done
EOF
echo "Finished creating /app/poll_s3.sh."

# --------------------------
# Start Placeholder Web Server
# --------------------------
echo "Creating placeholder files for health checks..."
echo "<h1>Health Check OK</h1>" > /app/index.html

# --- THIS IS THE FIX ---
mkdir -p /app/actuator
echo "OK" > /app/actuator/health
# -----------------------

echo "Starting placeholder web server with Python..."
cd /app/  # Make sure we are in the /app directory
nohup python3 -m http.server 80 --directory /app > /app/placeholder.log 2>&1 &
echo "Placeholder Python web server is running in the background."

# --------------------------
# Run the polling script
# --------------------------
echo "Making polling script executable..."
chmod +x /app/poll_s3.sh
echo "Starting polling script in the background..."
nohup /app/poll_s3.sh > /app/polling_service.log 2>&1 &
echo "Polling script is running in the background."

echo "User_data script finished."
