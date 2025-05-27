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

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"

    tags = {
        Name = "Bike-Videos"
    }
}

resource "aws_subnet" "public" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = "us-east-1a"
}

resource "aws_internet_gateway" "iwg" {
    vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.iwg.id
    }
}

resource "aws_route_table_association" "public_rt_assoc" {
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.public_rt.id
}

#we're only going to use this VPC for the ECS tasks so we only need the one security group
resource "aws_security_group" "ecs_sg" {
    vpc_id = aws_vpc.main.id

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_vpc_endpoint" "s3" {
    vpc_id = aws_vpc.main.id
    service_name = "com.amazonaws.us-east-1.s3"
    vpc_endpoint_type = "Gateway"
    route_table_ids = [aws_route_table.public_rt.id]
}