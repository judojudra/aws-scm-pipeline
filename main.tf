# 1. Provider Configuration 
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Ensure this matches your console view [cite: 32]
}

# 2. Capture Layer: S3 Bucket [cite: 3, 7]
resource "aws_s3_bucket" "data_capture" {
  bucket = "naars-event-driven-capture-2025" 
  # This bucket name must be unique across all of AWS.
}

# 3. Storage Layer: DynamoDB Table [cite: 3, 21]
resource "aws_dynamodb_table" "data_storage" {
  name           = "DailyDataLog"
  billing_mode   = "PAY_PER_REQUEST" # Scalability choice [cite: 25]
  hash_key       = "TransactionID"

  attribute {
    name = "TransactionID"
    type = "S"
  }
}