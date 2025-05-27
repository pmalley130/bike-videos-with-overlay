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

#bucket we upload source video to
data "aws_s3_bucket" "upload_bucket" {
    bucket = var.input_bucket_name
}

#role that allows the bucket to invoke lambda
resource "aws_lambda_permission" "allow_s3" {
    statement_id = "AllowS3Invoke"
    action = "lambda:InvokeFunction"
    function_name = var.lambda_function_arn
    principal = "s3.amazonaws.com"
    source_arn = data.aws_s3_bucket.upload_bucket.arn
}

#actual notification
resource "aws_s3_bucket_notification" "json_notification" {
    bucket = data.aws_s3_bucket.upload_bucket.id

    eventbridge = true
    
    lambda_function {
      lambda_function_arn = var.lambda_function_arn
      events = ["s3:ObjectCreated:*"]
      filter_suffix = ".json"
    }

  
    depends_on = [aws_lambda_permission.allow_s3]
}

#bucket where rendered video goes
data "aws_s3_bucket" "output_bucket" {
  bucket = var.output_bucket_name
}