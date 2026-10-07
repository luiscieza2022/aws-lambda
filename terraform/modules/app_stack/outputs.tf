output "api_upload_url" {
  description = "URL publica para subir imagenes"
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/upload"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.images.id
}