#!/bin/bash 
set -e;
#cd $(dirname $0);

# ❓❓❓ export vars by jenkins
ci_compose_cpus=${ci_compose_cpus:-1}
ci_compose_memory=${ci_compose_memory:-512M}
ci_compose_replicas=${ci_compose_replicas:-1}
ci_compose_service=${ci_compose_service}
ci_router_prefix=${ci_router_prefix:-$ci_compose_service}
ci_dockerfile=${ci_compose_dockerfile:-Dockerfile}
ci_git_project=${ci_git_project}
# ❓❓❓
# 🔻🔻🔻🔻🔻🔻🔻🔻🔻
CI_ENV="uat"
CI_DOCKER_CONTEXT_DEPLOY="${CI_ENV}-dss" #⛔部署service的docker环境
CI_DOCKER_CONTEXT_BUILD="default" #⛔构建image的docker环境
CI_DOCKER_NETWORK="uat_farm" #⛔service运行的docker网络
ci_service_port=81 #⛔service端口（traefik-loadbalancer.server.port）
ci_compose_image="ci3.devops.dss:5000/dss/${CI_ENV}/${ci_compose_service}:${CI_ENV}-${BUILD_NUMBER}" #⛔镜像tag&仓库
ci_env_profile=${ci_env_profile:-env}   #⛔docker env profile, 如：application.env.yaml
# /api-xxx-xxx
ci_env_app_path=${ci_router_prefix} #⛔docker env app_path
# work_dir
ci_work_dir="/opt/deploy/uat/${JOB_NAME}" #⛔构建目录
ci_git_host="ssh://git@ci2.devops.dss:10022" #git clone
ci_git_devops=${ci_git_host}/zyb/devops.git
ci_git_env_config=env/Stars_UAT.conf #⛔env-config@git
# 🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺

echo ">>📌 1. environments"
env

echo ">>📌 2. clone from git"
# 1. git clone && git archive <branch> --remote=ssh://git@xxx <prefix_path/xxx/xx> 
rm ${ci_work_dir} -rf && mkdir -p ${ci_work_dir} && cd ${ci_work_dir}
git archive --remote=${ci_git_devops} HEAD ${ci_git_env_config} | tar xO > ./config.env
git clone -b $ci_git_branch ${ci_git_host}/${ci_git_project} ${ci_work_dir}/src
cd $(realpath src/${ci_git_base}) # change the real source-code work-dir

# 2. build
# 执行打包
echo ">>📌 3. mvn clean package -q -Dmaven.test.skip=true -f pom.xml"
mvn clean package -q -Dmaven.test.skip=true -f pom.xml
# ls ./target

# 3. docker build
# git download single file
# git archive --remote=git@github.com:foo/bar.git --prefix=path/to/ HEAD:path/to/ |  tar xvf -
echo ">>📌 4. build image && push to registry"
export DOCKER_CONTEXT=${CI_DOCKER_CONTEXT_BUILD}
docker image prune -f
docker build --network host --force-rm --compress \
    --build-arg profile=${ci_env_profile} \
    --build-arg app_path=${ci_env_app_path} \
    -t "${ci_compose_image}" \
    -f ${ci_dockerfile} \
    . # Dockerfile context path

docker push ${ci_compose_image}

# deploy service
# --env-file .env \
echo ">>📌 5. deploy to farm"
# -- env-file
env_list=""
function read_env_file() {
    prefix=${1:-" -e "}
    while read LINE || [[ -n ${LINE} ]]
    do 
        s1=${LINE# }
        s1=${s1% }
        if [ ${#s1} = 0 ] || [ ${s1:0:1} = "#" ]
        then
            continue
        fi
        env_list+=${prefix}${s1}
    done < ../config.env
    printf "🔑🔑\n${env_list}\n🔑🔑\n"
}

# deploy to docker_context@remote
NEED_UPDATE_SERVICE=1
export DOCKER_CONTEXT=${CI_DOCKER_CONTEXT_DEPLOY}
#docker service inspect --pretty ${ci_compose_service} || NEED_UPDATE_SERVICE=0
docker service inspect --format service_id={{.ID}} ${ci_compose_service} || NEED_UPDATE_SERVICE=0

if [ "${NEED_UPDATE_SERVICE}" = "1" ] 
then
    echo ">>✅ Start update service..."
    env_list="" && read_env_file " --env-add " && \
    docker service update -d ${env_list} \
        --label-add "traefik.http.routers.${ci_compose_service}.entrypoints=zyb" \
        --label-add "traefik.http.routers.${ci_compose_service}.service=${ci_compose_service}" \
        --label-add "traefik.http.routers.${ci_compose_service}.rule=PathPrefix(\`${ci_router_prefix}\`)" \
        --label-add "traefik.http.services.${ci_compose_service}.loadbalancer.server.port=81" \
        --limit-cpu ${ci_compose_cpus} \
        --limit-memory ${ci_compose_memory} \
        --replicas ${ci_compose_replicas} \
        --image ${ci_compose_image} \
        ${ci_compose_service}
    echo ">>✅ update service success."
else
    echo ">>🟢 Start create service..."
    env_list="" && read_env_file " -e " && \
    docker service create -d --mode replicated ${env_list} \
        --network ${CI_DOCKER_NETWORK} \
        --update-parallelism 1 \
        --update-delay 20s \
        --name ${ci_compose_service} \
        --limit-cpu ${ci_compose_cpus} \
        --limit-memory ${ci_compose_memory} \
        --replicas ${ci_compose_replicas} \
        --label cigo="zyb" \
        --label "traefik.enable=true" \
        --label "traefik.http.routers.${ci_compose_service}.entrypoints=zyb" \
        --label "traefik.http.routers.${ci_compose_service}.service=${ci_compose_service}" \
        --label "traefik.http.routers.${ci_compose_service}.rule=PathPrefix(\`${ci_router_prefix}\`)" \
        --label "traefik.http.services.${ci_compose_service}.loadbalancer.server.port=${ci_service_port}" \
        ${ci_compose_image} # create new service

    echo ">>🟢 create service success"
fi

echo ">>📌 6. service inspect"
docker service inspect --pretty ${ci_compose_service}
