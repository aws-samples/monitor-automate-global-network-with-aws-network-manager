# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# --- terraform/infrastructure.tf ---

# ---------- AWS TRANSIT GATEWAY RESOURCES ----------
# Transit Gateway
resource "aws_ec2_transit_gateway" "tgw" {
  provider = aws.awsinfra

  description                     = "TGW - Network Manager automation"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = {
    Name = "tgw-nm-automation"
  }
}

# Transit Gateway route table
resource "aws_ec2_transit_gateway_route_table" "tgw_rt" {
  provider = aws.awsinfra

  transit_gateway_id = aws_ec2_transit_gateway.tgw.id

  tags = {
    Name = "tgw-rt-nm-automation"
  }
}

# AWS Systems Manager parameter
resource "aws_ssm_parameter" "tgw_rt_parameter" {
  provider = aws.awsinfra

  name        = "/nm-automation/tgw-route-table"
  description = "Transit Gateway Route Table ID"
  type        = "String"
  value       = aws_ec2_transit_gateway_route_table.tgw_rt.id
}

# ---------- AWS NETWORK MANAGER ----------
resource "aws_networkmanager_global_network" "global_network" {
  provider = aws.awsinfra

  description = "Global Network - Network Manager automation"

  tags = {
    Name = "global-network-nm-automation"
  }
}

resource "aws_networkmanager_transit_gateway_registration" "tgw_registration" {
  provider = aws.awsinfra

  global_network_id   = aws_networkmanager_global_network.global_network.id
  transit_gateway_arn = aws_ec2_transit_gateway.tgw.arn
}

# ---------- VPC RESOURCES ----------
module "vpc" {
  source    = "aws-ia/vpc/aws"
  version   = "4.3.0"
  providers = { aws = aws.awsinfra }
  count = var.deploy_vpc ? 1 : 0

  name       = "vpc-nm-automations"
  cidr_block = "10.0.0.0/24"
  az_count   = 2

  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  transit_gateway_routes = {
    private = "0.0.0.0/0"
  }

  subnets = {
    private = { netmask = 28 }
    transit_gateway = {
      netmask                                         = 28
      transit_gateway_default_route_table_association = false
      transit_gateway_default_route_table_propagation = false
    }
  }

}