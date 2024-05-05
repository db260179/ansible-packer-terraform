FROM $BASE_IMAGE

ARG AWSCLI_VERSION

ARG PASSWORD
ARG USERUID
ARG USERGID

LABEL maintainer="David Bentham <db260179@gmail.com>"
LABEL aws_cli_version=${AWSCLI_VERSION}

ENV DEBIAN_FRONTEND=noninteractive
ENV AWSCLI_VERSION=${AWSCLI_VERSION}

# Add ansible user and group and set password
RUN groupadd -g ${USERGID} ansible && useradd -ms /bin/bash -g ansible -u ${USERUID} ansible; echo "ansible:${PASSWORD}" | chpasswd

COPY docker-entrypoint.sh /

# Modify ssh_config for ansible user
# SSH allow users to login
RUN rm -rf /run/nologin; \
    echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config \
    && echo "ConnectTimeout 10" >> /etc/ssh/ssh_config

# Setup SSH key and permissions
COPY ssh /home/ansible/.ssh

RUN chown -R ansible: /home/ansible/.ssh; chmod 700 /home/ansible/.ssh; chmod 600 /home/ansible/.ssh/*

RUN echo "" > /etc/sysctl.conf && /usr/bin/ssh-keygen -A

# Change the .env to override this timezone
ENV TIMEZONE Europe/London

# Install Ansible and required software
RUN apt-get update \
    && apt-get install -y ansible curl gnupg unzip make nano openssh-client openssh-server software-properties-common

# Install AWS cli command
RUN curl -LO https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip \
    && unzip '*.zip' \
    && rm *.zip \
    && ./aws/install -i /usr/local/aws-cli -b /usr/local/bin \
    && rm -R aws   

# Hashicorp - Add official repo and install packer and terraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | \
    tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y packer terraform

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /home/ansible

# Set default directory and aliases in .bashrc
RUN echo 'cd /home/ansible/ansible-code' >> /home/ansible/.bashrc

CMD ["/bin/bash"]

ENTRYPOINT /docker-entrypoint.sh
