#### devops cicd

- Jenkins run command on Remote Shell

```shell Jenkins Remote Shell command
set -e
export ci_image="hello:dev-${BUILD_NUMBER}"
export ci_stack="vip-api-app-01"
export url_dockerfile="https://git/dockerfile"
export url_compose="https://git/compose.yaml"

sh ~/.devops4ci.sh
```

- ~/.devops4ci.sh

```shell
set -e

# see environments
env

# the follow can write into an script.sh file
# wget url -O new-filename
#wget https://raw.githubusercontent.com/softlang-net/devops-docker-cli/main/cli.Dockerfile
#wget https://raw.githubusercontent.com/softlang-net/devops-docker-cli/main/compose.yaml
wget $url_dockerfile -O cli.Dockerfile
wget $url_compose -O compose.yaml

# build
docker-compose -f compose.yaml build --force-rm
# push
docker-compose -f compose.yaml push
# purne
docker image prune -f
# docker deploy to swarm
docker stack deploy --prune --with-registry-auth -c compose.yml ${ci_stack}
```
