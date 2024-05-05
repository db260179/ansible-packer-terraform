# ansible-packer-terraform

Docker container that has Ansible, Hashicorp - Packer and Terraform installed

Docker image contains:
  
  * ansible
  * awscli                        v2.1.29
  * packer
  * terraform

## Building Docker Image
```
./control.sh docker-compose.yml build
```

## Examples

```
./control.sh docker-compose.yml config - Get config layout from your docker-compose.yml file

./control.sh docker-compose.yml start - Start the ansible-packer-terraform container

./control.sh docker-compose.yml logs - Watch the ansible-packer-terraform container runtime
```