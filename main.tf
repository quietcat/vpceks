terraform {
  required_providers {
    aws = {
      version = "~> 4.30.0"
    }
  }
}

variable "cluster_name" {
    type = string
}

variable "oidc_url" {
    type = string
}

variable "oidc_arn" {
    type = string
}

variable "account_id" {
    type = string
}

variable "region" {
    type = string
}

provider "aws" {
  region  = var.region
}

module "aws_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-2a", "us-east-2b"]
  public_subnets  = ["10.0.0.0/25", "10.0.0.128/25"]
  private_subnets = ["10.0.1.0/25", "10.0.1.128/25"]

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  enable_nat_gateway = true
  single_nat_gateway = true
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  map_public_ip_on_launch = false

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

data "aws_vpc" "eks" {
  id = "${module.aws_vpc.vpc_id}"
}


data "aws_subnets" "private" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.eks.id]
  }

  tags = {
    Name = "${var.cluster_name}-private-*"
  }
}

data "aws_subnets" "public" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.eks.id]
  }

  tags = {
    Name = "${var.cluster_name}-public-*"
  }
}



module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.29.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.22"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  vpc_id     = "${module.aws_vpc.vpc_id}"

  subnet_ids = concat(
    sort(data.aws_subnets.private.ids),
    sort(data.aws_subnets.public.ids),
  )

  eks_managed_node_groups = {
   default = {
      min_size     = 2
      max_size     = 2
      desired_size = 2

      subnet_ids = data.aws_subnets.private.ids
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
   }
 }
}

data "aws_security_group" "node_security_group" {
    filter {
        name = "tag:Name"
        values = ["${var.cluster_name}-node"]
    }
}

data "aws_security_group" "cluster_security_group" {
    filter {
        name = "tag:Name"
        values = ["${var.cluster_name}-cluster"]
    }
}

resource "aws_security_group_rule" "alb_control" {
    security_group_id = data.aws_security_group.node_security_group.id
    type = "ingress"
    protocol = "tcp"
    from_port = 9443
    to_port = 9443
    source_security_group_id = data.aws_security_group.cluster_security_group.id
    description = "Cluster API to ALB"
}
