#TODO: ecs, stepfunction/machine, eventbridge
#root module structure to keep all this TF straight
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

module "networking" {
  source = "./modules/networking"
}

module "lambda" {
  source            = "./modules/lambda"
  input_bucket_name = var.input_bucket_name
}

module "s3" {
  source               = "./modules/s3"
  input_bucket_name    = var.input_bucket_name
  output_bucket_name   = var.output_bucket_name
  lambda_function_arn  = module.lambda.lambda_function_arn
}

module "ecs" {
  source             = "./modules/ecs"
  ecr_repo_name      = var.ecr_repo_name
  vpc_id             = module.networking.vpc_id
  subnet_id          = module.networking.subnet_id
  ecs_sg_id          = module.networking.ecs_sg_id
  input_bucket_name  = var.input_bucket_name
  output_bucket_name = var.output_bucket_name
}