FROM ubuntu:20.04 as build

# Generic runner tools (utils)
RUN apt-get update -y
RUN apt-get install -y sudo kmod build-essential uuid-runtime jq git curl wget libmysqlclient-dev

# Docker setup
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN echo 'deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable' > /etc/apt/sources.list.d/docker.list
RUN DEBIAN_FRONTEND=noninteractive apt-get update -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io

# Github runner setup
RUN curl -so /tmp/actions-runner-linux-x64-2.305.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.305.0/actions-runner-linux-x64-2.305.0.tar.gz

RUN useradd -s /bin/bash -r -m github-runner
RUN usermod -aG docker github-runner
RUN echo 'github-runner ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/github-runner

RUN tar -C /home/github-runner -xzf /tmp/actions-runner-linux-x64-2.305.0.tar.gz
RUN rm -rf /tmp/actions-runner-linux-x64-2.305.0.tar.gz
RUN chown -R github-runner:github-runner /home/github-runner

ADD entrypoint.sh /usr/sbin/entrypoint.sh
RUN chmod 755 /usr/sbin/entrypoint.sh

# Flatten container to 1 layer
FROM ubuntu:20.04
ENV GITHUB_ORG=''
ENV GITHUB_TOKEN=''
COPY --from=build / /
ENTRYPOINT ["/usr/sbin/entrypoint.sh"]
