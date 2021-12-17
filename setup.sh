#!/bin/bash

CONFIG_BUCKET_NAME=$([ $# -gt 0 ] && echo $1 || echo "mgt-jenkins-configuration")

echo CONFIG_BUCKET_NAME=${CONFIG_BUCKET_NAME}

REGION=$(aws configure get region)

EXISTING_BUCKET=$(aws s3api list-buckets \
--query "Buckets[?Name == '${CONFIG_BUCKET_NAME}'].Name | [0]" | sed -e 's/"//g')

echo EXISTING_BUCKET=${EXISTING_BUCKET}

if [ ${EXISTING_BUCKET} == "null" ]; then
    echo "Creating configuration bucket..."
    aws s3 mb s3://${CONFIG_BUCKET_NAME} --region ${REGION}
else
    echo "Configuration bucket exists"
fi

aws s3 cp --recursive \
    assets/jenkins/controller \
    s3://${CONFIG_BUCKET_NAME}/jenkins/controller

echo "Deploying setup stack..."

STACK_NAME="jenkins-on-ecs-setup"

aws cloudformation create-stack \
--stack-name ${STACK_NAME} \
--template-body file://setup.yaml \
--parameters ParameterKey=ConfigurationBucketARN,ParameterValue=arn:aws:s3:::${CONFIG_BUCKET_NAME} \
--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
--disable-rollback \
--region ${REGION}

echo "Waiting for stack to create..."

aws cloudformation wait stack-create-complete \
--stack-name ${STACK_NAME}
