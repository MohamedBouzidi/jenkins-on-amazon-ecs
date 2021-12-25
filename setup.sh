#!/bin/bash

STACK_NAME="jenkins-on-ecs-setup"
CONFIG_BUCKET_NAME=$([ $# -gt 0 ] && echo $1 || echo "mgt-jenkins-configuration")
JENKINS_REPOSITORY_NAME="${STACK_NAME}-jenkins-controller"

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

echo "Checking if repository exists already..."

aws ecr describe-repositories --repository-name ${JENKINS_REPOSITORY_NAME} > /dev/null 2>&1 && \
echo "Jenkins repository exists. Deleting..." && \
aws ecr delete-repository --repository-name ${JENKINS_REPOSITORY_NAME} --force

echo "Deploying setup stack..."

aws cloudformation create-stack \
--stack-name ${STACK_NAME} \
--template-body file://setup.yaml \
--parameters \
    ParameterKey=ConfigurationBucketARN,ParameterValue=arn:aws:s3:::${CONFIG_BUCKET_NAME} \
    ParameterKey=JenkinsControllerRepositoryName,ParameterValue=${JENKINS_REPOSITORY_NAME} \
--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
--disable-rollback \
--region ${REGION}

echo "Waiting for stack to create..."

aws cloudformation wait stack-create-complete \
--stack-name ${STACK_NAME}

echo "Exporting repository information..."

res=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} \
    --query "Stacks[0].Outputs[*].{name: OutputKey, value: OutputValue} | [].join('=', [name,value]) | @.join('#', @)" |\
     sed -e 's/"//g' | tr '#' '\n')

eval $(echo $res | while read e
do
    echo "export ${e}"
done)

echo "Custom Jenkins image generated. Deleting stack..."

aws cloudformation delete-stack --stack-name ${STACK_NAME}

aws cloudformation wait stack-delete-complete \
--stack-name ${STACK_NAME}