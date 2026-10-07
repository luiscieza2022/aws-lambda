resource "random_id" "suffix" {
  byte_length = 4
}

# S3 Bucket
resource "aws_s3_bucket" "images" {
  bucket        = "image-processor-${var.environment}-${random_id.suffix.hex}"
  force_destroy = true
}

# SQS Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  name                      = "image-processor-${var.environment}-image-dlq"
  message_retention_seconds = 1209600
}

# SQS Main Queue
resource "aws_sqs_queue" "main" {
  name                       = "image-processor-${var.environment}-image-queue"
  visibility_timeout_seconds = 360
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# Política de SQS para permitir eventos de S3
resource "aws_sqs_queue_policy" "sqs_policy" {
  queue_url = aws_sqs_queue.main.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.main.arn
      Condition = {
        ArnLike = { "aws:SourceArn" = aws_s3_bucket.images.arn }
      }
    }]
  })
}

# Notificación de S3 a SQS al subir a uploads/
resource "aws_s3_bucket_notification" "s3_to_sqs" {
  bucket = aws_s3_bucket.images.id

  queue {
    queue_arn     = aws_sqs_queue.main.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }
}