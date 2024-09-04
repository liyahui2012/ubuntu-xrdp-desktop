#!/bin/bash

NAME=ubuntu-xrdp-desktop
DATADIR=data/${NAME}
RDP_PORT=13389
SSH_PORT=2222
MEM_LIMIT=8g

mkdir -p ${DATADIR}

docker run -d --name ${NAME} \
    --hostname ${NAME} \
    --restart always \
    --shm-size 1g \
    --cap-add SYS_ADMIN \
    --ulimit core=0 \
    -m ${MEM_LIMIT} \
    -p ${RDP_PORT}:3389 \
    -p ${SSH_PORT}:22 \
    -v /etc/localtime:/etc/localtime \
    -v ${DATADIR}/home:/home \
    -v ${DATADIR}/ssh:/etc/ssh \
    -e LANG=zh_CN.UTF-8 \
    -e AUTO_CREATE_SSH_USER=true \
    -e AUTO_KILL_INACTIVE_USER=true \
    -e SUDO_NOPASSWD=true \
    -e DEFAULT_UMASK=027 \
    alvinleee/ubuntu-xrdp-desktop:v1-22.04-utils
