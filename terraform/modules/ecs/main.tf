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

###########
# CLUSTER #
###########

resource "aws_ecs_cluster" "render_cluster" {
  name = "video-render-cluster"
}

##################
# EXECUTION ROLE #
##################

#actual permissions
data "aws_iam_policy_document" "ecs_execution_role_policy" { 
    statement {
      actions = ["sts:AssumeRole"]
      principals {
        type        = "Service"
        identifiers = ["ecs-tasks.amazonaws.com"]
      }
      effect = "Allow"
    }
}

#make the role
resource "aws_iam_role" "ecs_execution_role" {
    name               = "ecs-execution-role"
    assume_role_policy = data.aws_iam_policy_document.ecs_execution_role_policy.json
}

#also attach the default permissiosn for grabbing containers
resource "aws_iam_role_policy_attachment" "execution_role_policy_aws_managed" {
    role       = aws_iam_role.ecs_execution_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#######################################
# TASK ROLE (WHAT THE CONTAINER USES) #
#######################################

#actual task permissions
data "aws_iam_policy_document" "ecs_task_execution_role" { 
    statement {
      sid       = "S3ReadInputBucket"
      effect    = "Allow"
      actions   = [
        "s3:GetObject"
      ]
      resources = [
        "arn:aws:s3:::${var.input_bucket_name}/*"
      ]
    }
    statement {
      sid       = "S3WriteOutputBucket"
      effect    = "Allow"
      actions   = [
        "s3:PutObject"
      ]
      resources = [
        "arn:aws:s3:::${var.output_bucket_name}/*"
      ]
    }
}

#permissions of the role the container is assuming
data "aws_iam_policy_document" "ecs_task_assume_role" {
    statement {
      sid     = "InheritRole"
      effect  = "Allow"
      actions = ["sts:AssumeRole"]
      principals {
        type        = "Service"
        identifiers = ["ecs-tasks.amazonaws.com"]
        }
    }
}

#make the role for execution
resource "aws_iam_role" "render_task_role" {
    name               = "ecs-render-task-role"
    assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

#the policy
resource "aws_iam_policy" "render_task_policy" {
    name        = "ecs-task-s3-access"
    description = "Allows the rendering ECS task to download and upload files to the proper buckets"
    policy      = data.aws_iam_policy_document.ecs_task_execution_role.json
}

#attach policy to role that's being assumed
resource "aws_iam_role_policy_attachment" "render_task_policy_attachment" {
    role       = aws_iam_role.render_task_role.name
    policy_arn = aws_iam_policy.render_task_policy.arn
}

#############
# ECR SETUP #
#############

data "aws_ecr_repository" "ecr_repo" {
    name = var.ecr_repo_name
}

###################
# TASK DEFINITION #
###################

resource "aws_ecs_task_definition" "render_task" {
    family                   = "burn-subs"
    requires_compatibilities = ["FARGATE"]
    network_mode             = "awsvpc"
    cpu                      = "8192"
    memory                   = "32768"
    ephemeral_storage {
      size_in_gib = 50
    }
    execution_role_arn = aws_iam_role.ecs_execution_role.arn
    task_role_arn      = aws_iam_role.render_task_role.arn
    runtime_platform {
      cpu_architecture        = "X86_64"
      operating_system_family = "LINUX"
    }

    container_definitions = jsonencode([
        {
            name      = "burn-subs"
            image     = "${data.aws_ecr_repository.ecr_repo.repository_url}:latest"
            cpu       = 0
            essential = true

            environment = [
                {
                    name = "OUTBUCKET"
                    value = "${var.output_bucket_name}"
                },
                {
                    name = "BUCKET"
                    value = "${var.input_bucket_name}"
                }
            ]

            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    awslogs-group         = "/ecs/burn-subs"
                    mode                  = "non-blocking"
                    awslogs-create-group  = "true"
                    max-buffer-size       = "25m"
                    awslogs-region        = "us-east-1"
                    awslogs-stream-prefix = "ecs"
                }
            }

            portMappings = [
                {
                    name          = "burn-subs-80-tcp"
                    containerPort = 80
                    hostPort      = 80
                    protocol      = "tcp"
                    appProtocol   = "http"
                },
                {
                    name          = "burn-subs-443-tcp"
                    containerPort = 443
                    hostPort      = 443
                    protocol      = "tcp"
                    appProtocol   = "http2"
                }
            ]
        }
    ])
}