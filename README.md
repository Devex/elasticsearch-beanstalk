# ElasticSearch AWS Cluster

This project is the special configuration for AWS Elastic Beanstalk service. It
uses empty java-8 service and installs proper ElasticSearch version during
deployment stage.

## Prerequisites

Make sure you have installed

 - AWS Beanstalk [CLI Tools](http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb-cli3.html)

You'll need to ensure you have an [IAM Service Role for this](http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/iam-servicerole.html#iam-servicerole-create).

If you plan to deploy the new cluster in a VPC, you will need also the following:
 - VPC ID
 - VPC Subnets, might be different for EC2 instances and ELB
 - VPC Security Groups

## Deployment

### Init the EB application

Ensure you have your credentials loaded as environment variables.

```bash
$ eb init
```

This process will ask you about the region, application, and default environment.
The region should be us-east-1, unless you are doing some other kind of deploy.
The application we use to deploy an ES cluster is called `es-cluster`.
As default environment, choose Develop one, so in case of mistake nothing great should get broken.

**Please remember that our default application name is `es-cluster`**

### Configuration

Few environment variables, in `.env.example`, have to be specified before deployment:

 - `CLUSTER_NAME`: This is a name of your new shiny ElasticSearch cluster, please enforce something like `es-test-my-feature`
 - `AWS_KEY_ID`: AWS Key ID, skip changing it if your AWS access key ID is exported to `AWS_ACCESS_KEY_ID`.
 - `AWS_KEY`: AWS Secret Key, skip changing it if your AWS secret is exported to `AWS_SECRET_ACCESS_KEY`.
 - `AWS_REGION`: Region in which ES cluster will be created
 - `EC2_TAG_NAME`: This value should be equal to the AWS Name tag (same as environment name)
 - `MASTER_NODES`: Amount of master nodes, should be 1 for most test cases. The rule is simple, this number should equal to total number of nodes (N) divided by 2 plus 1. `N / 2 + 1`.
 - `PORT`: Should always be set to 9200, unless you changed ES http port.

### Usage of `.env` file

See example in `.env.example` file.
You can create a copy of this file, like `.env.my-feature, and set the previously explained variables there.

**Notice this file will not be committed anywhere**

### Create new cluster

In order to create new cluster, **out of VPC**, you need to execute following bash commands

```bash
$ ENV_VARS=$(cat .env.my-feature | xargs | sed -e 's/ /,/g' -e "s/XXXXXXXX/${AWS_ACCESS_KEY_ID}/g" -e "s/YYYYYYYY/${AWS_SECRET_ACCESS_KEY}/g")
$ eb create -c company-es-test-my-feature --envvars ${ENV_VARS} --platform=java-8 -i m3.large --scale 1 es-test-my-feature --service-role aws-elasticbeanstalk-elasticsearch-service-role
```

To use a **VPC**, you need to execute following bash commands

```bash
$ ENV_VARS=$(cat .env.my-feature | xargs | sed -e 's/ /,/g' -e "s/XXXXXXXX/${AWS_ACCESS_KEY_ID}/g" -e "s/YYYYYYYY/${AWS_SECRET_ACCESS_KEY}/g")
$ eb create -c company-es-test-telegraf-vpc --envvars ${ENV_VARS} --platform=java-8 -i m3.large --scale 1 es-test-telegraf-vpc --service-role aws-elasticbeanstalk-elasticsearch-service-role --vpc.id ${VPC_ID} --vpc.ec2subnets ${VPC_EC2_SUBNETS} --vpc.elbsubnets ${VPC_EC2_SUBNETS} --vpc.securitygroups ${VPC_SECURITYGROUPS}
```

Where `company-es-test-my-feature` is a CNAME; `es-test-my-feature` is the Elastic Beanstalk environment name; `m3.large` is a instance type and `--scale 1` is how many nodes to create

### Configure AWS Security Groups

After environment is created you need to change AWS Security Group rules. You have to allow all 9300-9400 TCP and ICMP traffic within SG group.

### Deploy changes

```bash
$ eb deploy es-test-my-feature
```

Where `es-test-my-feature` is a environment name

## Important Notes

 - Do not scale down the cluster during peak times, this will cause cluster move shards around also some pending requests may fail
 - When adding new nodes to cluster some requests may fail
 - When added new nodes to cluster remember to change `MASTER_NODES` var
