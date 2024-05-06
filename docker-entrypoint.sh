#!/bin/bash
/usr/sbin/init
# Set container to timezone
ln -fs /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

# Change the permissions of the vault_pass
if [ -f "/home/ansible/.vault_pass" ]; then
chown ansible:ansible /home/ansible/.vault_pass
fi

# Function to check if a file exists
file_exists() {
  if [ -f "$1" ]; then
    return 0
  else
    return 1
  fi
}

# Ansible collections requirements install
if file_exists "/home/ansible/ansible-code/collections/requirements.yml"; then
  su - ansible -c "ansible-galaxy install -r /home/ansible/ansible-code/collections/requirements.yml"
fi

# Ansible community general - proxmox
su - ansible -c "ansible-galaxy collection install community.general"

# Ansible terraform provider
su - ansible -c "ansible-galaxy collection install cloud.terraform"

# Ansible role requirements install
if file_exists "/home/ansible/ansible-code/roles/requirements.yml"; then
  su - ansible -c "ansible-galaxy install -r /home/ansible/ansible-code/roles/requirements.yml"
fi

# Read the Docker socket path from the environment variable
DOCKER_SOCKET_PATH=$HOST_DOCKER_GID

# Get the GID of the Docker socket group
DOCKER_SOCKET_GID=$(stat -c '%g' $DOCKER_SOCKET_PATH)

# Check if the group exists in the container
if getent group $DOCKER_SOCKET_GID >/dev/null; then
  echo "Group with GID $DOCKER_SOCKET_GID already exists."
  echo "Adding ansible to the existing $DOCKER_SOCKET_GID"
  # Add the `ansible` user to the group with the matching GID
  usermod -aG $DOCKER_SOCKET_GID ansible
else
  # Create the group with the matching GID
  groupadd -g $DOCKER_SOCKET_GID dockerhost
  usermod -aG dockerhost ansible
fi

# Start SSH daemon
/usr/sbin/sshd -D -e
