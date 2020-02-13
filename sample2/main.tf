provider "aws" {
  region = "eu-west-3"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-s3-resource-sample"

  # Prevent accidental deletion of this S3 bucket
  lifecycle {
      prevent_destroy = true
  }

  # Enable versioning so we can see the full revision history of our state files
  versioning {
      enabled = true
  }  

  # Enable server-side encryption by default
  server_side_encryption_configuration {
      rule {
          apply_server_side_encryption_by_default {
              sse_algorithm = "AES256"
          }
      }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-dynamodb-resource-sample"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
      name = "LockID"
      type = "S"
  }
}

terraform {
    # Terraform backend example
    backend "s3" {
        bucket         = "terraform-s3-resource-sample"
        key            = "global/s3/terraform.tfstate"
        region         = "eu-west-3"
        dynamodb_table = "terraform-dynamodb-resource-sample"
        encrypt        = true
    }
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.terraform_state.arn
  description = "The ARN of the s3 bucket"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "The name of the DynamoDB table"
}


