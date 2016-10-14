#!/bin/bash

function install() {
    if [ $(uname -s) == 'Darwin' ]; then
        if which brew &> /dev/null; then
            brew install awsebcli
        else
            echo "You must install Homebrew in your Mac to use this."
            exit -1
        fi
    elif [ $(uname -s) == 'Linux' ]; then
        if which pip &> /dev/null; then
            pip install awsebcli
        else
            easy_install pip
            pip install awsebcli
        fi
    fi
}

function setup() {
    if [ -z "${AWS_ACCESS_KEY_ID}" -o -z "${AWS_SECRET_ACCESS_KEY}" ]; then
        echo "You must export your credentials in AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY."
        exit -1
    fi
    if [ ! -f config/elasticsearch-${version}.yml ]; then
        echo "You must create an appropriate elasticsearch.yml file for your version"
        exit -1
    fi
    eb init ${application} -r ${region} -p ${platform} -k ${default_key}
}

function deploy() {
    git checkout -B ${cluster_name}
    echo "CLUSTER_NAME=${cluster_name}" > .env
    echo "AWS_KEY_ID=${AWS_ACCESS_KEY_ID}" >> .env
    echo "AWS_KEY=${AWS_SECRET_ACCESS_KEY}" >> .env
    echo "AWS_REGION=${region}" >> .env
    echo "EC2_TAG_NAME=${cluster_name}" >> .env
    echo "MASTER_NODES=${nodes}" >> .env
    echo "PORT=9200" >> .env
    ENV_VARS=$(cat .env | xargs | sed 's/ /,/g')
    sed -i.bak -e "s/ES_VER=2.1.0/ES_VER=${version}/g" .ebextensions/00_setup_elasticsearch.config
    rm .ebextensions/00_setup_elasticsearch.config.bak
    cp config/elasticsearch-${version}.yml config/elasticsearch.yml
    if [ "${version}" == "0.90.10" ]; then
        PROCFILE="web:ES_CLASSPATH=/usr/local/elasticsearch-0.90.10/lib/*"
        PROCFILE=${PROCFILE}" JAVA_OPTS='-Des.path.conf=/var/app/current/config"
        PROCFILE=${PROCFILE}" -Des.path.data=/var/esdata'"
        PROCFILE=${PROCFILE}" /opt/aws/bin/elasticsearch"
        sed -i.bak \
            -e "s/\${CLUSTER_NAME}/${cluster_name}/g" \
            -e "s/\${MASTER_NODES}/${nodes}/g" \
            -e "s/\${AWS_KEY_ID}/${AWS_ACCESS_KEY_ID}/g" \
            -e "s/\${AWS_KEY}/${AWS_SECRET_ACCESS_KEY}/g" \
            -e "s/\${AWS_REGION}/${region}/g" \
            -e "s/\${EC2_TAG_NAME}/${cluster_name}/g" \
            config/elasticsearch.yml
        rm config/elasticsearch.yml.bak
    else
        PROCFILE="web:/opt/aws/bin/elasticsearch --path.conf=/var/app/current/config"
    fi
    echo ${PROCFILE} > Procfile
    git commit -am "Deploy ${cluster_name}"
    eb create \
       -c ${cluster_name} \
       --envvars ${ENV_VARS} \
       --platform=${platform} \
       -i ${instance_type} \
       --scale ${nodes} \
       ${cluster_name}
    git checkout master
}

if [ -z "${1}" ]; then
    echo "You must specify an organization name."
    exit -1
fi

if [ -z "${2}" ]; then
    echo -n "You must specify a default SSH key, "
    echo "which must exist in your ~/.ssh or in your AWS account."
    exit -1
fi

if [ -z "${3}" ]; then
    echo "You must specify an environment."
    exit -1
fi

application=es-cluster
platform=java8
company=${1}
default_key=${2}
environment=${3}
region=${4-us-east-1}
version=${5-2.1.0}
network=${6-classic}
nodes=${7-2}
instance_type=${8-m3.large}
cluster_name=${company}-${environment}-${network}

if [ ! $(which eb &> /dev/null) ]; then
    if [ ! -d .elasticbeanstalk ]; then
        setup
    fi
    deploy
else
    install
fi
