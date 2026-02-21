FROM python:3.10-slim-bookworm

# Install SSH server (to act as both controller and target)
RUN apt-get update && \
    apt-get install -y openssh-server sshpass && \
    rm -rf /var/lib/apt/lists/*

# Configure SSH server
RUN mkdir /var/run/sshd && \
    echo 'root:testpass' | chpasswd && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Verify /bin/sh is dash (the shell that triggers the bug)
RUN ls -la /bin/sh && readlink -f /bin/sh

# Install ansible-core 2.17.7 (the broken version)
RUN pip install --no-cache-dir ansible-core==2.17.7

# Create repro directory
WORKDIR /repro

# Inventory pointing at localhost via SSH
RUN echo '[testhost]\nlocalhost ansible_port=22 ansible_user=root ansible_password=testpass ansible_connection=smart' > inventory

# ansible.cfg
RUN printf '[defaults]\nhost_key_checking = False\nlibrary = ./library\n' > ansible.cfg

# Playbook
COPY playbook.yml .

# Modules
COPY library/ ./library/

# Entrypoint: start SSH, run the test
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
