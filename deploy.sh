#!/bin/bash

if [ -z "$1" ]; then
  echo "Branch name not provided."
  exit 1
fi

BRANCH_NAME=$1
PR_NUMBER=$2
REMOTE_USER="team-4"
REMOTE_HOST="91.229.239.118"
REPO_URL="https://github.com/neyo55/hng-team-4-docker-app.git"
REMOTE_DIR="/tmp/team4-$BRANCH_NAME"
TIMESTAMP=$(date +%s)
CONTAINER_INFO_FILE="/tmp/container_info_${BRANCH_NAME}_${PR_NUMBER}_${TIMESTAMP}.txt"

# Function to find a random available port in the range 4000-7000
find_random_port() {
    while true; do
        # Generate a random port between 4000 and 7000
        PORT=$((4000 + RANDOM % 3001))

        # Check if the port is available
        if ! lsof -i:$PORT >/dev/null; then
            break
        fi
    done
    echo $PORT
}

# Get an available random port
PORT=$(find_random_port)

# Unique container name based on branch, port, and PR number
CONTAINER_NAME="container_${BRANCH_NAME}_${PR_NUMBER}_${PORT}"

ssh -o LogLevel=ERROR -o StrictHostKeyChecking=no $REMOTE_USER@$REMOTE_HOST << EOF
  # Remove existing directory if it exists to avoid conflicts
  if [ -d "$REMOTE_DIR" ]; then
    rm -rf "$REMOTE_DIR"
  fi

  # Clone the repository
  git clone "$REPO_URL" "$REMOTE_DIR" || {
    echo "Failed to clone the repository"
    exit 1
  }

  # Navigate to the project directory
  cd "$REMOTE_DIR" || {
    echo "Failed to change directory to $REMOTE_DIR"
    exit 1
  }

  # Checkout the branch
  git checkout $BRANCH_NAME || {
    echo "Failed to checkout branch $BRANCH_NAME"
    exit 1
  }

  # Pull the latest changes from the branch
  git pull origin $BRANCH_NAME || {
    echo "Git pull failed"
    exit 1
  }

  # Build the Docker image with a unique tag
  docker build -t $CONTAINER_NAME .

  # Run the Docker container with the random port and unique container name
  docker run -d -p $PORT:80 --name $CONTAINER_NAME $CONTAINER_NAME

  # Save container name and port information to a file for cleanup
  echo "$CONTAINER_NAME $PORT" > $CONTAINER_INFO_FILE

  # Output the container name and deployment link
  echo "Container name: $CONTAINER_NAME"
  echo "Deployment complete: http://$REMOTE_HOST:$PORT"
EOF
