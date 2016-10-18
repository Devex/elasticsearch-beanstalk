#!/bin/bash

function install() {
    if [ $(uname -s) == 'Darwin' ]; then
        if which brew &> /dev/null; then
            brew install awsebcli
            brew install awscli
        else
            echo "You must install Homebrew in your Mac to use this."
            exit -1
        fi
    elif [ $(uname -s) == 'Linux' ]; then
        if which pip &> /dev/null; then
            pip install awsebcli
            pip install awscli
        else
            easy_install pip
            pip install awsebcli
            pip install awscli
        fi
    fi
}

function setup() {
    if [ -z "${AWS_ACCESS_KEY_ID}" -o -z "${AWS_SECRET_ACCESS_KEY}" ]; then
        echo -n "You must export your credentials in AWS_ACCESS_KEY_ID and"
        echo " AWS_SECRET_ACCESS_KEY."
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
    sed -i.bak \
        -e "s/ES_VER=2.1.0/ES_VER=${version}/g" \
        .ebextensions/00_setup_elasticsearch.config
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
        PROCFILE="web:/opt/aws/bin/elasticsearch"
        PROCFILE=${PROCFILE}" --path.conf=/var/app/current/config"
    fi
    echo ${PROCFILE} > Procfile
    git commit -am "Deploy ${cluster_name}"
    VPC_PARAMS=""
    if [ "$network" == "vpc" ]; then
        vpc_id=$(
            aws ec2 describe-vpcs \
                --filters "Name=tag:Name,Values=${environment}" \
                | grep VpcId | tr -d ' ' | cut -d\| -f4)
        if [ "${vpc_id}" == "" ]; then
            echo "No VPC found for ${environment}"
            exit -1
        fi
        echo "Using VPC ${vpc_id} for ${environment}"
        subnet_ids=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${vpc_id}" "Name=tag:Name,Values=*ublic*" | grep SubnetId | tr -d ' ' | cut -d\| -f4 | tr "\n" ',' | sed -e 's/,$//')
        sg_id=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=${vpc_id}" "Name=group-name,Values=elasticsearch-${environment}" | egrep "^\|\|  GroupId" | tr -d ' ' | cut -d\| -f4)
        VPC_PARAMS="--vpc --vpc.id ${vpc_id} --vpc.ec2subnets ${subnet_ids}"
        VPC_PARAMS=${VPC_PARAMS}" --vpc.elbsubnets ${subnet_ids} --vpc.elbpublic"
        VPC_PARAMS=${VPC_PARAMS}" --vpc.publicip"
        VPC_PARAMS=${VPC_PARAMS}" --vpc.securitygroups ${sg_id}"
    fi
    echo "Creating cluster ${cluster_name}"
    eb create \
       -c ${cluster_name} \
       --envvars ${ENV_VARS} \
       --platform=${platform} \
       -i ${instance_type} \
       --scale ${nodes} \
       ${VPC_PARAMS} \
       ${cluster_name}
    if [ "$network" == "classic" ]; then
        instance_ids=$(eb list -v | grep ${cluster_name} | cut -d: -f2 | tr -d "' \[\]" | tr ',' ' ')
        sg=$(aws ec2 describe-instances --instance-ids ${instance_ids} | egrep "^\|{3}  GroupId" | uniq | cut -d\| -f5 | tr -d ' ')
        aws ec2 authorize-security-group-ingress --protocol tcp --port 9200-9400 --source-group ${sg} --group-id ${sg}
        aws ec2 authorize-security-group-ingress --protocol icmp --port -1 --source-group ${sg} --group-id ${sg}
    fi
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
