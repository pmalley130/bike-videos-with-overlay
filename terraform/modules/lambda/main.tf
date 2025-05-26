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

#save account number to variable for use in IAM ARN stuff
data "aws_caller_identity" "current" {}
locals {
    account_id = data.aws_caller_identity.current.account_id
}

#IAM roles
data "aws_iam_policy_document" "lambda_assume_role" { #function role statement
    statement {
      actions = ["sts:AssumeRole"]
      principals {
        type        = "Service"
        identifiers = ["lambda.amazonaws.com"]
      }
    }
}

resource "aws_iam_role" "lambda_exec_role" {
    name = "generateSubsLambdaRole"
    assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

#IAM policy doc
#json for the lambda but fancy terraform style - allows us to validate first
data "aws_iam_policy_document" "lambda_subs_role_policy_doc" {
    statement {
        sid      = "S3GetPut"
        effect   = "Allow"
        actions  = [
            "s3:GetObject",
            "s3:PutObject"
        ]
        resources = [
            "arn:aws:s3:::${var.input_bucket_name}"
        ]
    }
    statement {
        sid      = "SSMRead"
        effect   = "Allow"
        actions  = [
            "ssm:Get*"
        ]
        resources = [
            "arn:aws:ssm:us-east-1:${local.account_id}:parameter/*"
        ]
    }
    statement {
        sid       = "KMSDecrypt"
        effect    = "Allow"
        actions   = [
            "kms:Decrypt"
        ]
        resources = [
            "arn:aws:kms:*:${local.account_id}:key/*"
        ]
    }
}

resource "aws_iam_role_policy" "lambda_subs_role_policy" {
    name   = "lambda_subs_role_policy"
    role   = aws_iam_role.lambda_exec_role.id
    policy = data.aws_iam_policy_document.lambda_subs_role_policy_doc.json
}

#resource "aws_iam_role_policy_attachment" "lambda_exec_role" {
#    role       = aws_iam_role.lambda_exec_role.name
#   policy_arn = aws_iam_role_policy.lambda_subs_role_policy.arn
#}

#the actual function
resource "aws_lambda_function" "generate_subs" {
    function_name = "generate_subs"
    role          = aws_iam_role.lambda_exec_role.arn
    handler       = "lambda_function.lambda_handler"
    runtime       = "python3.11"
    filename      = "lambda_function.zip"
    timeout       = 120
}