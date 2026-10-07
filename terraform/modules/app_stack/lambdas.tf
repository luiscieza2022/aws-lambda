# Zips temporales
data "archive_file" "upload_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../../../lambdas/upload"
  output_path = "${path.module}/upload.zip"
}

data "archive_file" "crop_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../../../lambdas/crop"
  output_path = "${path.module}/crop.zip"
}

# IAM Role para Lambda Upload
resource "aws_iam_role" "upload_role" {
  name = "upload-lambda-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "upload_basic" {
  role       = aws_iam_role.upload_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_policy" "upload_s3_policy" {
  name = "upload-s3-policy-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${aws_s3_bucket.images.arn}/uploads/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "upload_s3" {
  role       = aws_iam_role.upload_role.name
  policy_arn = aws_iam_policy.upload_s3_policy.arn
}

# Security Group para Lambdas
resource "aws_security_group" "lambda_sg" {
  name        = "lambda-sg-${var.environment}"
  vpc_id      = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Upload Lambda
resource "aws_lambda_function" "upload" {
  filename         = data.archive_file.upload_zip.output_path
  function_name    = "upload-lambda-${var.environment}"
  role             = aws_iam_role.upload_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  memory_size      = 256
  timeout          = 30

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      S3_BUCKET     = aws_s3_bucket.images.id
      UPLOAD_PREFIX = "uploads/"
    }
  }
}

# IAM Role para Crop Lambda
resource "aws_iam_role" "crop_role" {
  name = "crop-lambda-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "crop_basic" {
  role       = aws_iam_role.crop_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_policy" "crop_policy" {
  name = "crop-policy-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.images.arn}/uploads/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.images.arn}/processed/*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.main.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "crop_attach" {
  role       = aws_iam_role.crop_role.name
  policy_arn = aws_iam_policy.crop_policy.arn
}

# Crop Lambda
resource "aws_lambda_function" "crop" {
  filename         = data.archive_file.crop_zip.output_path
  function_name    = "crop-lambda-${var.environment}"
  role             = aws_iam_role.crop_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  memory_size      = 512
  timeout          = 60

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      S3_BUCKET        = aws_s3_bucket.images.id
      PROCESSED_PREFIX = "processed/"
    }
  }
}

# SQS Trigger hacia Crop Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.main.arn
  function_name    = aws_lambda_function.crop.arn
  batch_size       = 5
}