#!/bin/bash
#
# Script to control docker-compose

if [ "${DEBUG}" = "true" ]; then
  set -ex
else
  set -e
fi

MYNAME=$(basename "$0")
HERE=$(dirname "$0")
TIMEOUT=30	# shutdown timeout

# If a global .env doesnt exist then use our default
if [ ! -f "${HERE}/.env" ]; then
    echo "Global ENV doesn't exist, copying templated version"
    cp -a "${HERE}/env_templates/env" "${HERE}/.env"
fi

# These are set here so that they are in the environment for starting/stopping etc.
if [[ ! $EUID -ne 0 ]]; then
	echo "Do not run this script as a ROOT user!"
	exit 1
else
	export USERUID=$(id -u)
	export USERGID=$(id -g)
	sed -i 's|USERUID=.*|USERUID='"$USERUID"'|' "${HERE}/.env"
	sed -i 's|USERGID=.*|USERGID='"$USERGID"'|' "${HERE}/.env"
fi


# Make sure we have docker login set for the registry
if [[ ! -z "$JENKINS" ]]; then
    echo "Jenkins jobs, skipping docker login check!"
else
    if [ ! -f "$HOME/.docker/config.json" ];then
       echo "Docker login not set!"
       echo "Login into the docker registry with your AD account!"
       echo "'docker login docker-registry.lvs.co.uk'"
       exit 1
    fi
fi

# Create a private ssh key if it doesnt exist
if [ ! -f "${HERE}/ssh/id_rsa" ]; then
  echo "Private SSH key does not exist? - Creating one!"
  echo "Make sure to distribute the public key on remote nodes!"
  ssh-keygen -t rsa -f ssh/id_rsa
  echo "Copy this ssh public key to remote hosts!"
  cat ssh/id_rsa.pub
fi

# Create an authorized_keys file if it doesn't exist
if [ ! -f "${HERE}/authorized_keys" ]; then
  echo "authorized_keys doesn't exist! - creating one"
  echo "Add your ssh public key to this file to access the ansible-packer-terraform container"
  touch "${HERE}/authorized_keys"
  chmod 0600 "${HERE}/authorized_keys"
  sleep 5
  exit 1
fi

# Reset permissions for authorized_keys
if [ -f "${HERE}/authorized_keys" ]; then
  echo "authorized_keys permissions reset!"
  chmod 0600 "${HERE}/authorized_keys"
fi

# Check if Docker is installed
if ! command -v docker &>/dev/null; then
  echo "Error: Docker is not installed."
  read -p "Would you like to run the setup_docker.sh script to install Docker? (y/n): " choice
  case "$choice" in
    y|Y )
      sudo ./setup_docker.sh
      ;;
    * )
      echo "Docker engine needs to be installed for this to run!"
      exit 1
      ;;
  esac
fi

if which docker-compose > /dev/null 2>&1; then
    dockercomposecmd="docker-compose"
elif which docker > /dev/null 2>&1 && docker compose > /dev/null 2>&1; then
    dockercomposecmd="docker compose"
else
    echo "Error: docker-compose or docker compose not found. Please install either one and try again."
    exit 1
fi

usage() {
	echo
	echo "Usage: ${MYNAME} [composefile] [command]"
	echo
	echo "	Commands: config clear-images build push-images start stop stop-down stop-down-clear-img stop-down-vol stop-clear-all logs"
	echo
	echo "	Example: ./${MYNAME} (composefile) config - Show docker-compose config for ansible-control-node"
	exit 0
	echo
}

composefile=""

if [ "$1" != "" ]; then
	composefile="-f ${HERE}/$1"
fi

if [ "$composefile" = "" ]; then
	echo "Please specify your compose config i.e. docker-compose.yml"
	exit 1
fi

case "$2" in
	config*)
		${dockercomposecmd} ${composefile} config
		;;
	clear-images)
		${dockercomposecmd} ${composefile} down --rmi all
		docker system prune -f
		;;
	build)
		${dockercomposecmd} ${composefile} build
		;;
	push-images)
		${dockercomposecmd} ${composefile} push
		;;
	start|run)
		${dockercomposecmd} ${composefile} up -d
		source .env
		echo "Control-node: 'ssh -o \"UserKnownHostsFile=/dev/null\" -o \"StrictHostKeyChecking=no\" ansible@localhost -p $SSH_PORT'"
		echo ""
		;;
	stop)
		${dockercomposecmd} ${composefile} stop
		;;
	stop-down)
		${dockercomposecmd} ${composefile} down --timeout ${TIMEOUT}
		;;
	stop-down-clear-img)
		${dockercomposecmd} ${composefile} down --rmi all --timeout ${TIMEOUT}
		docker image prune -f
		;;
	stop-down-vol)
		${dockercomposecmd} ${composefile} down -v --timeout ${TIMEOUT}
		;;
	stop-clear-all)
		${dockercomposecmd} ${composefile} down --timeout ${TIMEOUT}
		docker system prune -a -f
		;;
	log*)
		${dockercomposecmd} ${composefile} logs -f
		;;
	*)
		usage
		;;
esac
