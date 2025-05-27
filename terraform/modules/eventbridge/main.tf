terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

###############
# PERMISSIONS #
###############

data "aws_iam_policy_document" "eventbridge_role_policy" {
    statement {
      actions = ["sts:AssumeRole"]
      principals {
        type = "Service"
        identifiers = ["events.amazonaws.com"]
      }
      effect = "Allow"
    }
}

resource "aws_iam_role" "eventbridge_role" {
    name = "eventbridge-to-step-function-role"
    assume_role_policy = data.aws_iam_policy_document.eventbridge_role_policy.json
}

data "aws_iam_policy_document" "eventbridge_policy" {
    statement {
        sid = "StartStateMachine"
        effect = "Allow"
        actions = ["states:StartExecution"]
        resources = [var.render_ecs_state_machine]
    }
}

resource "aws_iam_role_policy" "eventbridge_policy" {
    name = "eventbridge-policy"
    role = aws_iam_role.eventbridge_role.id
    policy = data.aws_iam_policy_document.eventbridge_policy.json
}

##############
# EVENT RULE #
##############

resource "aws_cloudwatch_event_rule" "subtitle_upload_rule" {
    name = "s3-subs-upload-trigger"
    description = "Trigger step function when .ass file uploaded"

    event_pattern = jsonencode({
        source = ["aws.s3"],
        "detail-type" = ["Object Created"],
        detail = {
            bucket = {
                name = [var.input_bucket_name]
            },
            object = {
                key = [{
                    suffix = ".ass"
                }]
            }
        }
    })
}

resource "aws_cloudwatch_event_target" "step_function_target" {
  rule = aws_cloudwatch_event_rule.subtitle_upload_rule.name
  arn = var.render_ecs_state_machine
  role_arn = aws_iam_role.eventbridge_role.arn
}