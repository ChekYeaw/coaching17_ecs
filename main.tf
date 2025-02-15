

locals {
     prefix = "chek" # provide your name prefix
}

resource "aws_ecr_repository" "ecr" {
  name         = "${local.prefix}-ecr"
  force_delete = true
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.9.0"

  cluster_name = "${local.prefix}-ecs"
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  services = {
    chek-flask-ecs-taskdef =  {
      cpu    = 512
      memory = 1024
      container_definitions = {
        Flask-app = {
          essential = true
          image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${local.prefix}-ecr:latest"
          port_mappings = [
            {
              containerPort = 8080
              protocol      = "tcp"
            }
          ]
        }
      }
      assign_public_ip                   = true
      deployment_minimum_healthy_percent = 100
      subnet_ids                   = ["subnet-076e61b23ab466c1b"] #List of subnet IDs to use for your tasks
      security_group_ids           = [aws_security_group.ecs_sg.id] #Create a SG resource and pass it here
    }
  }
}

## Data Source ##

data "aws_vpc" "existing" {
  id = "vpc-04c2b4e7800c6298a"  # Your existing VPC ID
}

data "aws_caller_identity" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

data "aws_region" "current" {}

## Security Group Resource ##

resource "aws_security_group" "ecs_sg" {
  name        = "${local.prefix}-ecs-sg"
  description = "Allow inbound HTTP traffic for ECS tasks"
  vpc_id = data.aws_vpc.existing.id

  # Ingress (inbound) rules - allow traffic on port 80 from any source
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow traffic from any source
  }

  # Egress (outbound) rules - allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all protocols
    cidr_blocks = ["0.0.0.0/0"]  # Allow traffic to any destination
  }

  tags = {
    Name = "ECS Security Group"
  }
}


