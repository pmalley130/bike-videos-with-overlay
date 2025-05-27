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

data "aws_iam_policy_document" "step_function_role" {
    statement {
      actions = ["sts:AssumeRole"]
      principals {
        type = "Service"
        identifiers = ["states.amazonaws.com"]
      }
      effect = "Allow"
    }
}

resource "aws_iam_role" "step_function_role" {
    name = "render-step-function-ecs-policy"
    assume_role_policy = data.aws_iam_policy_document.step_function_role.json
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "step_function_policy" {
    statement {
        sid = "StepFunctionRunTask"
        effect = "Allow"
        actions = [
            "ecs:RunTask",
        ]
        resources = [var.task_definition]
    }
    statement {
      sid = "StepFunctionPassTaskRoles"
      effect = "Allow"
      actions = ["iam:PassRole"]
      resources = [
        var.render_task_role,
        var.ecs_execution_role
      ]
    }
    statement {
        sid    = "AllowNetworking"
        effect = "Allow"
        actions = [
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeNetworkInterfaces",
            "ec2:CreateNetworkInterface",
            "ec2:DeleteNetworkInterface",
            "ec2:DescribeVpcs"
        ]
        resources = ["*"]
    }
    statement {
        sid    = "AllowEventBridgeManagedRule"
        effect = "Allow"
        actions = [
            "events:PutRule",
            "events:PutTargets",
            "events:DescribeRule",
            "events:DeleteRule",
            "events:RemoveTargets"
        ]
        resources = [
            "arn:aws:events:us-east-1:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForECSTaskRule"
        ]
    }
}

resource "aws_iam_role_policy" "step_function_policy" {
    name = "step-function-ecs-policy"
    role = aws_iam_role.step_function_role.id
    policy = data.aws_iam_policy_document.step_function_policy.json
}

#################
# STATE MACHINE #
#################

resource "aws_sfn_state_machine" "render_ecs_state_machine" {
    name     = "render-from-s3-state-machine"
    role_arn = aws_iam_role.step_function_role.arn

    definition = jsonencode({
        Comment = "Trigger ECS Task from S3 subtitle upload event",
        StartAt = "RunECSTask",
        States  = {
            RunECSTask = {
                Type       = "Task",
                Resource   = "arn:aws:states:::ecs:runTask.sync",
                Parameters = {
                    LaunchType           = "FARGATE",
                    Cluster              = "${var.cluster_name}",
                    TaskDefinition       = "${var.task_definition}",
                    NetworkConfiguration = {
                        AwsvpcConfiguration = {
                            Subnets        = ["${var.subnet_id}"],
                            SecurityGroups = ["${var.ecs_sg_id}"]
                            AssignPublicIp = "ENABLED"
                        }
                    },
                    Overrides = {
                        ContainerOverrides = [
                            {
                                Name = "burn-subs"
                                Environment = [
                                    {
                                        Name = "SUBS_KEY"
                                        Value = "$.detail.object.key"
                                    }
                                ]
                            }
                        ]
                    }
                },
                End = true
            }
        }
    })
}
