locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_dynamodb_table" "review_requests" {
  name         = "${local.name_prefix}-review-requests"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "request_id"

  attribute {
    name = "request_id"
    type = "S"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-review-requests"
  })
}

resource "aws_sqs_queue" "review_requests_dlq" {
  name = "${local.name_prefix}-review-requests-dlq"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-review-requests-dlq"
  })
}

resource "aws_sqs_queue" "review_requests_queue" {
  name                       = "${local.name_prefix}-review-requests"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.review_requests_dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-review-requests"
  })
}

resource "aws_sns_topic" "review_notifications" {
  name = "${local.name_prefix}-review-notifications"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-review-notifications"
  })
}

resource "aws_sns_topic_subscription" "email_notification" {
  topic_arn = aws_sns_topic.review_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_custom_policy" {
  name = "${local.name_prefix}-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_custom_attach" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_custom_policy.arn
}

resource "aws_lambda_function" "processor_lambda" {
  function_name = "${local.name_prefix}-processor"

  filename         = "lambda/processor/function.zip"
  source_code_hash = filebase64sha256("lambda/processor/function.zip")

  handler = "index.lambda_handler"
  runtime = "python3.9"

  role = aws_iam_role.lambda_execution_role.arn

  environment {
   variables = {
    TABLE_NAME    = aws_dynamodb_table.review_requests.name
    SNS_TOPIC_ARN = aws_sns_topic.review_notifications.arn
   }
  }

  tags = local.common_tags
}

resource "aws_lambda_event_source_mapping" "processor_sqs_trigger" {
  event_source_arn = aws_sqs_queue.review_requests_queue.arn
  function_name    = aws_lambda_function.processor_lambda.arn
  batch_size       = 1
  enabled          = true
}

resource "aws_lambda_function" "ingestor_lambda" {
  function_name = "${local.name_prefix}-ingestor"

  filename         = "lambda/ingestor/function.zip"
  source_code_hash = filebase64sha256("lambda/ingestor/function.zip")

  handler = "index.lambda_handler"
  runtime = "python3.9"

  role = aws_iam_role.lambda_execution_role.arn

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.review_requests.name
      QUEUE_URL  = aws_sqs_queue.review_requests_queue.url
    }
  }

  tags = local.common_tags
}

resource "aws_apigatewayv2_api" "review_api" {
  name          = "${local.name_prefix}-review-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type"]
  }

  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "ingestor_integration" {
  api_id                 = aws_apigatewayv2_api.review_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.ingestor_lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "submit_review_route" {
  api_id    = aws_apigatewayv2_api.review_api.id
  route_key = "POST /submit-review"
  target    = "integrations/${aws_apigatewayv2_integration.ingestor_integration.id}"
}

resource "aws_apigatewayv2_stage" "dev" {
  api_id      = aws_apigatewayv2_api.review_api.id
  name        = "$default"
  auto_deploy = true

  tags = local.common_tags
}

resource "aws_lambda_permission" "allow_apigw_invoke_ingestor" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestor_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.review_api.execution_arn}/*/*"
}