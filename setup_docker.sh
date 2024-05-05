#!/bin/bash

if [ "${DEBUG}" = "true" ]; then
  set -ex
else
  set -e
fi

# Function to display error messages and exit
function error_exit {
  echo "Error: $1" >&2
  exit 1
}

# Check if the script is run with sudo
if [ "$EUID" -ne 0 ]; then
  error_exit "Please run this script with sudo."
fi

# Check if the OS is Rocky Linux, CentOS 7 or Debian
if [ -f /etc/os-release ]; then
  source /etc/os-release
  if [[ "$ID" != "rocky" && "$ID" != "centos" ]] && "$ID" != "debian" ]]; then
    error_exit "This script is only compatible with Rocky Linux, CentOS 7 and Debian."
  fi
else
  error_exit "Unable to determine the operating system."
fi

# Check if Docker is installed
if ! command -v docker &>/dev/null; then
  echo "Docker is not installed. Installing Docker..."

  # Add Centos Docker repository
  repo_centos_url="https://download.docker.com/linux/centos/docker-ce.repo"
  
  # Setup Debian Docker repository
  debian_setup() {
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
  }

  if [ "$ID" == "centos" ]; then
    yum install -y yum-utils
    yum-config-manager --add-repo=$repo_centos_url
  elif [ "$ID" == "rocky" ]; then
    dnf install -y yum-utils
    dnf config-manager --add-repo=$repo_centos_url
  elif [ "$ID" == "debian" ]; then
    debian_setup
  else
    error_exit "Unsupported distribution: $ID."
  fi

  # Install Docker
  if [ "$ID" == "rocky" ]; then
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  elif [ "$ID" == "centos" ]; then
    yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  elif [ "$ID" == "debian" ]; then
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi

  # Check if the installation was successful
  if [ $? -eq 0 ]; then
    echo "Docker installed successfully."

    # Add predefined users to the docker group
    source .env
    for user in $LOCAL_USERS; do
      usermod -aG docker $user
      echo "User '$user' added to the 'docker' group."
    done

    echo "Please log out and log back in for the changes to take effect."

    # Enable and start the Docker systemd service
    systemctl enable docker
    systemctl start docker

    echo "Docker systemd service enabled and started."

  else
    error_exit "Failed to install Docker. Please check the installation logs for more details."
  fi

else
  echo "Docker is already installed."
fi
