# docker build -f cli.Dockerfile -t
FROM alpine

ARG APK_REPOS="mirrors.cloud.tencent.com"
RUN sed -i "s/dl-cdn.alpinelinux.org/${APK_REPOS}/g" /etc/apk/repositories

RUN apk --no-cache --no-progress add openssh docker-cli \
    && update-ca-certificates \
    && rm -rf /var/cache/apk/*

# user and password
ARG P_USER=devops
ARG P_PASS=dev0ps
# remove root's password
RUN passwd -d root
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
RUN ssh-keygen -A

# add user & set passwd
RUN adduser -D ${P_USER}
RUN echo "${P_USER}:${P_PASS}" | chpasswd

# add user to docker group, to access docker api
ENV DOCKER_GROUP_ID="0"
ENV DOCKER_GROUP_NAME="nogroup"
RUN printf "set -e\n\
echo \n\
echo ---------- $(date +"%Y-%m-%d %H:%M:%S") ----------\n\
echo user=${P_USER}\n\
echo pass=${P_PASS}\n\
echo DOCKER_GROUP_ID=\${DOCKER_GROUP_ID}\n\
echo DOCKER_GROUP_NAME=\${DOCKER_GROUP_NAME}\n\
echo 'docker run -e DOCKER_GROUP_ID=xx -e DOCKER_GROUP_NAME=xx -v /var/run/docker.sock:/var/run/docker.sock:ro'\n\
\n\
if ! grep -q \${DOCKER_GROUP_NAME} /etc/group\n\
then\n\
addgroup -g \${DOCKER_GROUP_ID} \${DOCKER_GROUP_NAME}\n\
adduser ${P_USER} \${DOCKER_GROUP_NAME}\n\
fi\n\n\
/usr/sbin/sshd -D\n\
"> /start.sh
# with start.sh + chpasswd = change password on start..

ENTRYPOINT ["/bin/sh", "/start.sh"]
EXPOSE 22