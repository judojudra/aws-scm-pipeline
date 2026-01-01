
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


resource "aws_s3_bucket" "data_capture" {
  bucket = "naars-event-driven-capture-2026"
}


resource "aws_dynamodb_table" "data_storage" {
  name         = "DailyDataLog"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "TransactionID"

  attribute {
    name = "TransactionID"
    type = "S"
  }
}


resource "aws_iam_role" "lambda_role" {
  name = "scm_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}


resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}


data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}


resource "aws_lambda_function" "scm_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "ScmProcessorV2"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 128
}


resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scm_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data_capture.arn
}


resource "aws_s3_bucket_notification" "csv_trigger" {
  bucket = aws_s3_bucket.data_capture.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.scm_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}


output "s3_bucket_name" {
  value = aws_s3_bucket.data_capture.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.data_storage.name
}

output "lambda_function_name" {
  value = aws_lambda_function.scm_processor.function_name
}
