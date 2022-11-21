data "aws_caller_identity" "current" {}

provider "aws" {
  shared_credentials_files = ["~/.aws/credentials"]
  region = "eu-west-1"
  profile = "default"
}

terraform {
  backend "s3" {
    bucket         = "patryk-test"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    shared_credentials_file = "~/.aws/credentials"
    profile = "default"
  }
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  service = "cdkVsTfVsSlsVsCf-tf-example"
  tags = {
    serviceName = local.service
    version = "0.0.1"
  }
}

resource "aws_iam_role" "lambda_iam" {
  name = "${local.service}-lambda-role"
  tags = local.tags
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "revoke_keys_role_policy" {
  name = "${local.service}-lambda-role-policy"
  role = aws_iam_role.lambda_iam.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "s3:GetObject"
        ],
        "Effect": "Allow",
        "Resource": [
          aws_s3_bucket.bucket.arn,
          "${aws_s3_bucket.bucket.arn}*"
        ]
      },
      {
        "Action": [
          "dynamodb:PutItem"
        ],
        "Effect": "Allow",
        "Resource": [
          "${aws_dynamodb_table.table.arn}*"
        ]
      }
    ]
  })
}

resource "aws_lambda_function" "lambda" {
  function_name    = "${local.service}-lambda"
  role             = aws_iam_role.lambda_iam.arn
  handler          = "writer.handler"
  runtime          = "nodejs16.x"
  timeout          = 30
  filename         = "./out.zip"
  source_code_hash = filebase64sha256("./out.zip")
  environment {
    variables = {
      TABLE_NAME = "mock"
    }
  }
  tags = local.tags
}

resource "aws_s3_bucket" "bucket" {
  bucket = "${local.service}-bucket"
  tags = local.tags
}

resource "aws_s3_bucket_notification" "aws-lambda-trigger" {
  bucket = aws_s3_bucket.bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

resource "aws_lambda_permission" "lambda-permission" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.bucket.id}"
}

resource "aws_dynamodb_table" "table" {
  name           = "${local.service}-table"
  billing_mode   = "ON_DEMAND"
  hash_key       = "pk"

  attribute {
    name = "pk"
    type = "S"
  }
  tags = local.tags
  stream_enabled = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
}

resource "aws_kinesis_stream" "stream" {
  name        = "${local.service}-stream"
  shard_count = 1
  tags = local.tags
}

resource "aws_dynamodb_kinesis_streaming_destination" "dynamodb-stream" {
  stream_arn = aws_kinesis_stream.stream.arn
  table_name = aws_dynamodb_table.table.name
}
