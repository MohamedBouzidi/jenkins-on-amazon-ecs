#!/bin/bash

source ./setup.sh

REGION=$(aws configure get region)

CF_BUCKET=$(aws s3api list-buckets \
--query "Buckets[?starts_with(Name, 'cf-templates') && ends_with(Name, '${REGION}')].Name | [0]" | sed -e 's/"//g')

if [ "${CF_BUCKET}" = "null" ]; then
    echo "No bucket"
    exit 1
fi

echo "Found templates bucket: CF_BUCKET=${CF_BUCKET}"
echo "Packaging local files into template..."

aws cloudformation package \
--template-file main.yaml \
--s3-bucket ${CF_BUCKET} \
--output-template-file packaged.yaml

echo "Deploying stack..."

STACK_NAME="jenkins-on-ecs"

aws cloudformation create-stack --stack-name ${STACK_NAME} \
--template-body file://packaged.yaml \
--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
--parameters \
    ParameterKey=JenkinsControllerRepositoryUri,ParameterValue="${JenkinsControllerRepositoryUri}" \
    ParameterKey=JenkinsControllerRepositoryArn,ParameterValue="${JenkinsControllerRepositoryArn}" \
    ParameterKey=AdminUsername,ParameterValue="admin" \
    ParameterKey=AdminPassword,ParameterValue="password"

aws cloudformation wait stack-create-complete --stack-name ${STACK_NAME}

JENKINS_ENDPOINT=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} \
--query "Stacks[0].Outputs[?OutputKey == 'JenkinsWebUI'].OutputValue | [0]" | sed -e 's/"//g')

echo "Stack deployed. Access Jenkins WebUI through: ${JENKINS_ENDPOINT}"