
- devops cicd

```shell

```

- docker build scripts

```shell build scripts
# build image by cli.Dockerfile
set -e

image_name="cli-registry/devops:cli20.10.12"
# https://docs.docker.com/engine/reference/commandline/build/
#docker build --shm-size 268435456 --force-rm \
#    -f Dockerfile -t ${pre_name}/dockercli:v2.10.12 \
#    --add-host git.dev:10.11.11.1 \
#    --add-host repo1.dev:10.11.11.2 \
#    https://github.com/docker/cli.git#v20.10.12

# test pass
docker rmi ${image_name} || echo "no devops image"
docker build --shm-size 268435456 --force-rm -f cli.Dockerfile -t image_name .

# run
docker stop ops || echo "no container ops"
docker run -itd --rm --name ops -v /var/run/docker.sock:/var/run/docker.sock:ro \
-e DOCKER_GROUP_ID=114 -e DOCKER_GROUP_NAME=cli4docker -e TZ='Asia/Shanghai' -p 2022:22 \
${image_name}

#docker build --shm-size 268435456 --force-rm -t ${pre_name}/whoami:v1 https://github.com/traefik/whoami.git
#docker build --force-rm -f node.Dockerfile -t ${pre_name}/node:16.13-slim .
#docker build --shm-size 268435456 --force-rm -f gp.Dockerfile -t gp:6.17 .s
```