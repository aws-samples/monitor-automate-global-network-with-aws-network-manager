.PHONY: deploy undeploy

INFRASTRUCTURE_REGION ?= <AWS_REGION>
EMAIL_ADDRESS ?= <EMAIL>
SOLUTION_STACK_NAME ?= nm-automation-solution
INFRASTRUCTURE_STACK_NAME ?= nm-automation-infra

deploy: 
	aws cloudformation deploy --stack-name "${SOLUTION_STACK_NAME}" --template-file automation.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides EmailAddress="${EMAIL_ADDRESS}" --no-fail-on-empty-changeset --region us-west-2
	aws cloudformation deploy --stack-name "${INFRASTRUCTURE_STACK_NAME}" --template-file infrastructure.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset --region "${INFRASTRUCTURE_REGION}"
	
undeploy: 
	aws cloudformation delete-stack --stack-name "$(INFRASTRUCTURE_STACK_NAME)" --region "${INFRASTRUCTURE_REGION}"
	aws cloudformation delete-stack --stack-name "$(SOLUTION_STACK_NAME)" --region us-west-2