output "name_prefix" {
  value = local.name_prefix
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.review_requests.name
}

output "review_requests_queue_url" {
  value = aws_sqs_queue.review_requests_queue.url
}

output "review_requests_queue_arn" {
  value = aws_sqs_queue.review_requests_queue.arn
}

output "review_requests_dlq_arn" {
  value = aws_sqs_queue.review_requests_dlq.arn
}

output "sns_topic_arn" {
  value = aws_sns_topic.review_notifications.arn
}

output "processor_lambda_name" {
  value = aws_lambda_function.processor_lambda.function_name
}

output "ingestor_lambda_name" {
  value = aws_lambda_function.ingestor_lambda.function_name
}

output "api_gateway_url" {
  value = aws_apigatewayv2_api.review_api.api_endpoint
}

output "submit_review_endpoint" {
  value = "${aws_apigatewayv2_api.review_api.api_endpoint}/submit-review"
}



