# ============================================================================
# Grupo Hospitalario SanaVI - Red VPC y Subredes (Cumplimiento HIPAA)
# Asignatura: INY1106 - Infraestructura de Aplicaciones II
# ============================================================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "SanaVI-Hospital-Platform"
      Environment = "Production"
      Compliance  = "HIPAA-HITECH"
      Course      = "INY1106"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

resource "aws_vpc" "sanavi_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "sanavi-hipaa-vpc"
  }
}

# Subredes Públicas (API Gateway / Ingress ALB)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.sanavi_vpc.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "sanavi-public-us-east-1a", "kubernetes.io/role/elb" = "1" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.sanavi_vpc.id
  cidr_block              = "10.20.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags                    = { Name = "sanavi-public-us-east-1b", "kubernetes.io/role/elb" = "1" }
}

# Subredes Privadas de Aplicaciones (EKS Worker Nodes & Microservicios)
resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.sanavi_vpc.id
  cidr_block        = "10.20.11.0/24"
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "sanavi-private-eks-1a", "kubernetes.io/role/internal-elb" = "1" }
}

resource "aws_subnet" "private_app_b" {
  vpc_id            = aws_vpc.sanavi_vpc.id
  cidr_block        = "10.20.12.0/24"
  availability_zone = "${var.aws_region}b"
  tags              = { Name = "sanavi-private-eks-1b", "kubernetes.io/role/internal-elb" = "1" }
}

# Subredes Privadas Aisladas de Datos Clínicos y Financieros (RDS PostgreSQL Multi-AZ)
resource "aws_subnet" "isolated_db_a" {
  vpc_id            = aws_vpc.sanavi_vpc.id
  cidr_block        = "10.20.21.0/24"
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "sanavi-isolated-rds-hipaa-1a" }
}

resource "aws_subnet" "isolated_db_b" {
  vpc_id            = aws_vpc.sanavi_vpc.id
  cidr_block        = "10.20.22.0/24"
  availability_zone = "${var.aws_region}b"
  tags              = { Name = "sanavi-isolated-rds-hipaa-1b" }
}

# VPC Flow Logs para Auditoría de Red HIPAA
resource "aws_flow_log" "hipaa_vpc_flow_log" {
  iam_role_arn    = "arn:aws:iam::486923200363:role/LabRole"
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.sanavi_vpc.id
}
