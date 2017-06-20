FROM fedora:latest
MAINTAINER njbaker@outlook.com

RUN dnf update -y && \
    dnf install -y awscli && \
    dnf install -y findutils && \
    dnf install -y rsync

WORKDIR /root
ADD start.sh /root/start.sh

ENTRYPOINT ["/root/start.sh"]
