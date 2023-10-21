# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# --- terraform/automation.tf ---

# ---------- CREATION OF THE TRANSIT GATEWAY ROUTING ----------
# EventBridge Rule
resource "aws_cloudwatch_event_rule" "tgwrouting_eventbridge_rule" {
  provider = aws.awsoregon

  name        = "nm-tgw-routing"
  description = "Capture AWS Network Manager actions (VPC attachment related)."

  event_pattern = jsonencode({
    source      = ["aws.networkmanager"],
    detail-type = ["Network Manager Topology Change"],
    detail = {
      changeType = ["VPC-ATTACHMENT-CREATED", "VPC-ATTACHMENT-DELETED"]
    }
  })
}

# EventBridge Rule Target
resource "aws_cloudwatch_event_target" "tgwrouting_lambda_target" {
  provider = aws.awsoregon

  target_id = "StateMachine"
  arn       = aws_sfn_state_machine.state_machine.arn
  role_arn  = aws_iam_role.tgwrouting_eventbridge_statemachine_role.arn
  rule      = aws_cloudwatch_event_rule.tgwrouting_eventbridge_rule.id
}

# Amazon SNS Topic
resource "aws_sns_topic" "sns_topic" {
  provider = aws.awsoregon

  name = "nm-sns-topic"
}

resource "aws_sns_topic_subscription" "sns_topic_subscription" {
  provider = aws.awsoregon
  count    = var.email_address == "" ? 0 : 1

  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "email"
  endpoint  = var.email_address
}

# AWS Lambda Function - Creating TGW routing
resource "aws_lambda_function" "tgwrouting_function" {
  provider = aws.awsoregon

  function_name    = "tgw-routing-automation"
  filename         = "tgw_routing.zip"
  source_code_hash = data.archive_file.tgwrouting_lambda_package.output_base64sha256

  role    = aws_iam_role.tgwrouting_lambda_role.arn
  runtime = "python3.10"
  handler = "tgw_routing_function.lambda_handler"
  timeout = 10

  environment {
    variables = { PARAMETER_NAME = "/nm-automation/tgw-route-table" }
  }
}

data "archive_file" "tgwrouting_lambda_package" {
  type        = "zip"
  source_file = "../lambda_code/tgw_routing_function.py"
  output_path = "tgw_routing.zip"
}

# Lambda Function IAM Role
resource "aws_iam_role" "tgwrouting_lambda_role" {
  provider = aws.awsoregon

  name = "tgw-routing-lambda-role"
  path = "/"

  assume_role_policy = data.aws_iam_policy_document.tgwrouting_lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "tgwrouting_lambda_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM Policy - TGW routing configuration and Systems Manager Parameter
resource "aws_iam_policy" "tgwrouting_lambda_policy" {
  provider = aws.awsoregon

  name        = "tgw-routing-lambda-policy"
  path        = "/"
  description = "IAM policy - TGW routing and SSM parameter"

  policy = data.aws_iam_policy_document.tgwrouting_lambda_policy_document.json
}

data "aws_iam_policy_document" "tgwrouting_lambda_policy_document" {
  statement {
    sid    = "AllowTGWActions"
    effect = "Allow"
    actions = [
      "ec2:AssociateTransitGatewayRouteTable",
      "ec2:EnableTransitGatewayRouteTablePropagation"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "RetrieveSSMParameter"
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = ["*"]
  }
}

resource "aws_iam_policy_attachment" "tgwrouting_lambda_policy_attachment" {
  provider = aws.awsoregon

  name       = "tgwrouting-policy-attachment"
  roles      = [aws_iam_role.tgwrouting_lambda_role.id]
  policy_arn = aws_iam_policy.tgwrouting_lambda_policy.arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "tgwrouting_lambda_log_group" {
  provider = aws.awsoregon

  name              = "/aws/lambda/tgw-routing-automation"
  retention_in_days = 7
}

# EventBridge Target IAM Role
resource "aws_iam_role" "tgwrouting_eventbridge_statemachine_role" {
  provider = aws.awsoregon

  name = "eventbridge-stepfunctions-invoke"
  path = "/"

  assume_role_policy = data.aws_iam_policy_document.tgwrouting_eventbridge_statemachine_assume_role_policy.json
}

data "aws_iam_policy_document" "tgwrouting_eventbridge_statemachine_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

# IAM Policy - EventBridge invoking Step Functions state machine
resource "aws_iam_policy" "tgwrouting_eventbridge_statemachine_policy" {
  provider = aws.awsoregon

  name        = "eventbridge-stepfunctions-invoke"
  path        = "/"
  description = "EventBridge invoking Step Functions state machine."

  policy = data.aws_iam_policy_document.tgwrouting_eventbridge_statemachine_policy_document.json
}

data "aws_iam_policy_document" "tgwrouting_eventbridge_statemachine_policy_document" {
  statement {
    sid       = "InvokeStateMachine"
    effect    = "Allow"
    actions   = ["states:StartExecution"]
    resources = [ aws_sfn_state_machine.state_machine.arn ]
  }
}

resource "aws_iam_policy_attachment" "tgwrouting_eventbridge_statemachine_policy_attachment" {
  provider = aws.awsoregon

  name       = "tgwrouting_eventbridge_statemachine-policy-attachment"
  roles      = [aws_iam_role.tgwrouting_eventbridge_statemachine_role.id]
  policy_arn = aws_iam_policy.tgwrouting_eventbridge_statemachine_policy.arn
}

# Step Functions state machine
resource "aws_sfn_state_machine" "state_machine" {
  provider = aws.awsoregon

  name     = "nm-create-tgw-routing-automation"
  role_arn = aws_iam_role.state_machine_role.arn

  definition = jsonencode({
    Comment = "TGW Routing Automation",
    StartAt = "ActionType",
    States = {
      ActionType = {
        Type = "Choice",
        Choices = [
          {
            Variable     = "$.detail.changeType",
            StringEquals = "VPC-ATTACHMENT-CREATED",
            Next         = "CreateTGWRouting"
          }
        ],
        Default = "SendNotification"
      },
      CreateTGWRouting = {
        Type       = "Task",
        Resource   = "arn:aws:states:::lambda:invoke",
        ResultPath = null,
        Parameters = {
          "Payload.$"    = "$",
          "FunctionName" = aws_lambda_function.tgwrouting_function.arn
        },
        Retry = [
          {
            ErrorEquals = [
              "Lambda.ServiceException",
              "Lambda.AWSLambdaException",
              "Lambda.SdkClientException",
              "Lambda.TooManyRequestsException"
            ],
            IntervalSeconds = 1,
            MaxAttempts     = 3,
            BackoffRate     = 2
          }
        ],
        Next = "SendNotification"
      },
      SendNotification = {
        Type     = "Task",
        Resource = "arn:aws:states:::sns:publish",
        Parameters = {
          "TopicArn"  = aws_sns_topic.sns_topic.arn,
          "Message.$" = "$"
        },
        End = true
      }
    }
  })
}

# IAM Role - Step Functions state machine
resource "aws_iam_role" "state_machine_role" {
  provider = aws.awsoregon

  name = "sf-state_machine-role"
  path = "/"

  assume_role_policy = data.aws_iam_policy_document.state_machine_assume_role_policy.json
}

data "aws_iam_policy_document" "state_machine_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

# IAM Policy - Invoking Lambda Function, Publishing SNS Topic, CloudWatch & X-Ray Access
resource "aws_iam_policy" "state_machine_policy" {
  provider = aws.awsoregon

  name        = "sf-state_machine-policy"
  path        = "/"
  description = "Invoking Lambda Function, Publishing SNS Topic, CloudWatch & X-Ray Access."

  policy = data.aws_iam_policy_document.state_machine_policy_document.json
}

data "aws_iam_policy_document" "state_machine_policy_document" {
  statement {
    sid       = "InvokeLambdaFunction"
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.tgwrouting_function.arn]
  }

  statement {
    sid       = "AllowSNSPublish"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.sns_topic.arn]
  }

  statement {
    sid    = "CloudWatchLogsXRayAccess"
    effect = "Allow"
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups",
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy_attachment" "state_machine_policy_attachment" {
  provider = aws.awsoregon

  name       = "tgwrouting_eventbridge_statemachine-policy-attachment"
  roles      = [aws_iam_role.state_machine_role.id]
  policy_arn = aws_iam_policy.state_machine_policy.arn
}

# ---------- LOGGING VPN ACTIONS IN DYNAMODB ----------
# EventBridge Rule
resource "aws_cloudwatch_event_rule" "vpnactions_eventbridge_rule" {
  provider = aws.awsoregon

  name        = "nm-vpn-actions"
  description = "Capture AWS Network Manager actions (VPN related)."

  event_pattern = jsonencode({
    source      = ["aws.networkmanager"],
    detail-type = ["Network Manager Topology Change"],
    detail = {
      changeType = [
        { prefix = "VPN-ATTACHMENT-" },
        { prefix = "VPN-CONNECTION-" },
        { prefix = "VPN-TUNNEL-" }
      ]
    }
  })
}

# Target
resource "aws_cloudwatch_event_target" "vpnactions_eventbridge_target" {
  provider = aws.awsoregon

  arn  = aws_lambda_function.vpnactions_function.arn
  rule = aws_cloudwatch_event_rule.vpnactions_eventbridge_rule.id
}

# Lambda permission (for the EventBridge rule)
resource "aws_lambda_permission" "allow_vpnactions_eventbridge_rule" {
  provider = aws.awsoregon

  statement_id  = "EventBridgeToLambda"
  action        = "lambda:InvokeFunction"
  function_name = "vpn-actions-automation"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.vpnactions_eventbridge_rule.arn
}

# AWS Lambda Function - Logging VPN actions to DynamoDB
resource "aws_lambda_function" "vpnactions_function" {
  provider = aws.awsoregon

  function_name    = "vpn-actions-automation"
  filename         = "vpn_actions.zip"
  source_code_hash = data.archive_file.vpnactions_lambda_package.output_base64sha256

  role    = aws_iam_role.vpnactions_lambda_role.arn
  runtime = "python3.10"
  handler = "vpn_actions_function.lambda_handler"
  timeout = 10

  environment {
    variables = { TABLE_NAME = "network-manager-vpn-actions" }
  }
}

data "archive_file" "vpnactions_lambda_package" {
  type        = "zip"
  source_file = "../lambda_code/vpn_actions_function.py"
  output_path = "vpn_actions.zip"
}

# Lambda Function IAM Role
resource "aws_iam_role" "vpnactions_lambda_role" {
  provider = aws.awsoregon

  name = "vpn-actions-lambda-role"
  path = "/"

  assume_role_policy = data.aws_iam_policy_document.vpnactions_lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "vpnactions_lambda_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM Policy - TGW routing configuration and Systems Manager Parameter
resource "aws_iam_policy" "vpnactions_lambda_policy" {
  provider = aws.awsoregon

  name        = "vpn-actions-lambda-policy"
  path        = "/"
  description = "Adding items to DynamoDB table."

  policy = data.aws_iam_policy_document.vpnactions_lambda_policy_document.json
}

data "aws_iam_policy_document" "vpnactions_lambda_policy_document" {
  statement {
    sid       = "AllowDynamoDB"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.dynamodb_table.arn]
  }
}

resource "aws_iam_policy_attachment" "vpnactions_lambda_policy_attachment" {
  provider = aws.awsoregon

  name       = "vpn-actions-policy-attachment"
  roles      = [aws_iam_role.vpnactions_lambda_role.id]
  policy_arn = aws_iam_policy.vpnactions_lambda_policy.arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "vpnactions_lambda_log_group" {
  provider = aws.awsoregon

  name              = "/aws/lambda/vpn-actions-automation"
  retention_in_days = 7
}

# DynamoDB Table
resource "aws_dynamodb_table" "dynamodb_table" {
  name           = "network-manager-vpn-actions"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "vpn-id"
  range_key      = "changeType"

  attribute {
    name = "changeType"
    type = "S"
  }

  attribute {
    name = "vpn-id"
    type = "S"
  }
}