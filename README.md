# ElasticSearch AWS Cluster

This is a fork of https://github.com/vladmiller/elasticsearch-beanstalk.
The code added allows you to work with ES cluster creation in AWS Elasticbeanstalk.

## Prerequisites

You'll be asked for a ssh key to be used, when creating instances.
You should have it ready.
If planning to put your ES cluster in a VPC, you'll need to create an empty security group per environment called `${env_name}-elasticsearch`.

You will need to have [[https://github.com/poka-yoke/spaceflight/mcc/capcom][capcom]] available in your PATH as well.

## Usage

### Setup

Simple, just run `bin/setup` after clone, from the repository root, specifying a valid ssh key.

### Create new cluster

The command is `bin/create`, you'll need to specify an organization name, and the environment name.
You also can specify, as ordered arguments:

  - ES version to use, by default uses 2.1.0.
  - Network, i.e. `classic`, which is the default or `vpc`.
  - Region, defaulting to `us-east-1`.
  - Will create 2 nodes, unless specified otherwise.
  - Instance type to use, defaulting to m3.large.
  
### Modify parameters in cluster

To modify parameters like the maximum number of nodes to have, you'll use `bin/modify`, like the following:

    bin/modify cluster-name MaxSize='5'
    
If you want to change more options in the same command you can use this:

    bin/modify cluster-name UpperThreshold='70',LowerThreshold='30',Unit=Percent,MeasureName=CPUUtilization
    
That's the list of options it can modify:

  - UpperBreachScaleIncrement
  - LowerBreachScaleIncrement  
  - LowerThreshold  
  - MeasureName  
  - UpperThreshold  
  - Unit
  - MinSize  
  - Cooldown  
  - Availability Zones  
  - MaxSize
  - RollingUpdateType  
  - RollingUpdateEnabled

## Important Notes

 - Do not scale down the cluster during peak times, this will cause cluster move shards around also some pending requests may fail
 - When adding new nodes to cluster some requests may fail
 - When added new nodes to cluster remember to change `MASTER_NODES` var
