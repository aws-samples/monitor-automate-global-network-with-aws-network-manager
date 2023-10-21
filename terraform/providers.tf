# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# --- terraform/provider.tf ---

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# Provider definition for Oregon Region
provider "aws" {
  region = "us-west-2"
  alias  = "awsoregon"
}

# Provider definition for Stockholm Region
provider "aws" {
  region = var.infrastructure_region
  alias  = "awsinfra"
}