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

**All this section should be done only once**

Ensure you have your credentials loaded as environment variables.

```bash
$ eb init
```

This process will ask you about the region, application, and default environment.
The region should be us-east-1, unless you are doing some other kind of deploy.
The application we use to deploy an ES cluster is called `es-cluster`.
As default environment, choose Develop one, so in case of mistake nothing great should get broken.

**Please remember that our default application name is `es-cluster`**

In order to be able to deploy an ES cluster the nodes will need to query AWS API to get a list of running instances.
This can be achieved by reusing a service role the `init` command should be creating.

First, this service role needs some adjustments
* Add `sts:AssumeRole` and `ec2:DescribeInstances` Permissions
* Add `ec2.amazonaws.com` as a Trusted service

Finally, create a new instance profile called `elasticsearch`, and associate the role to it.

### Configuration for a new cluster

Few environment variables, in `.ebextensions/50_elasticsearch.config`, have to be specified before deployment:

 - `CLUSTER_NAME`: This is a name of your new shiny ElasticSearch cluster, please enforce something like `company-es-test-my-feature`. Must only contain letters, digits, and the dash caracter.
 - `AWS_REGION`: Region in which ES cluster will be created
 - `EC2_TAG_NAME`: This value should be equal to the AWS Name tag (same as environment name)
 - `MASTER_NODES`: Amount of master nodes, should be 1 for most test cases. The rule is simple, this number should equal to total number of nodes (N) divided by 2 plus 1. `N / 2 + 1`.
 - `PORT`: Should always be set to 9200, unless you changed ES http port.
 - `ES_JAVA_OPTS`: Set to 6g by default, allows to determine JVM heap size initial and maximum values, which, according to ES 5.6 documentation, must be the same size.

This file also describes the process to setup Elasticsearch.
 
In the `.ebextension/00_cloud.config`, a whole set of cloud provisioning definitions are included:
 - `InstanceType`: Instance type to use for the nodes.
 - `IamInstanceProfile`: IAM instance profile, which must exist. See Prerequisites.
 - `SecurityGroups`: Comma separated list of Security groups identifiers.
 - `BlockDeviceMappings`: Extra block devices needed. Example: "/dev/sdf=:300", will add a new 300Gb EBS volume. Review [documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/block-device-mapping-concepts.html) for other options.
 - `VPCId`: VPC identifier.
 - `Subnets`: Comma separated list of subnets for nodes allocation.
 - `ELBSubnets`: Comma separated list of subnets for ELB nodes allocation.
 - `ELBScheme`: Must be `internal`, making the cluster not to be accessible from outside the VPC.
 - `AssociatePublicIpAddress`: Must be `true` so the instances are able to reach EB control plane.
 - `ServiceRole`: Service role, which must exist. See Prerequisites.

This file also provides with the script to mount the NVMe volume. Notice that this will only work on instance types that will see the volumes as NVMe. Also, if the instance belongs to m5d, r5d or c5d, this volume might not be needed.

The file `.ebextensions/10_nginx.config` modifies Nginx configuration.

The file `.ebextensions/60_telegraf.config` defines telegraf setup.

### Create new cluster

Remember to export your AWS credentials before continuing.
You need to execute following commands:

```bash
CLUSTER_NAME=company-es-environment-myfeature

eb create -c ${CLUSTER_NAME} --platform=java-8 --scale 1 ${CLUSTER_NAME} --tags environment=$(echo ${CLUSTER_NAME} | awk -F- '{print $3}')
```

Where `CLUSTER_NAME` will be the CNAME and the Elastic Beanstalk environment name; these two must contain only letters, digits, and the dash character; `--scale 1` is how many nodes to create.

### Configure AWS Security Groups

After environment is created you need to change AWS Security Group rules. You have to allow all 9300-9400 TCP and ICMP traffic within SG group.

### Deploy changes

```bash
$ eb deploy ${CLUSTER_NAME}
```

Where `${CLUSTER_NAME}` is a environment name

## Important Notes

 - Do not scale down the cluster during peak times, this will cause cluster move shards around also some pending requests may fail
 - When adding new nodes to cluster some requests may fail
 - When added new nodes to cluster remember to change `MASTER_NODES` var
