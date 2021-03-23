variable "environment" {
  default = ""
}

variable "code_version" {
}

variable "domain_name" {
}

variable "aws_region" {
  default = "eu-west-1"
}

locals {
  suffix = var.environment == "" ? "" : "_${var.environment}"
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us-east-1"
  region = var.aws_region
}

resource "aws_lambda_function" "hello" {
  s3_bucket        = "spacelift-demo-preview-environments-service"
  s3_key           = "${var.code_version}.zip"
  function_name    = "hello${local.suffix}"
  role             = aws_iam_role.iam_for_lambda_tf.arn
  handler          = "index.handler"
  source_code_hash = var.code_version
  runtime          = "nodejs12.x"
}

resource "aws_iam_role" "iam_for_lambda_tf" {
  name               = "iam_for_lambda_tf${local.suffix}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_permission" "hello" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello.arn
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_rest_api" "hello" {
  name = "hello${local.suffix}"
}

resource "aws_api_gateway_resource" "hello" {
  rest_api_id = aws_api_gateway_rest_api.hello.id
  parent_id   = aws_api_gateway_rest_api.hello.root_resource_id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "hello" {
  rest_api_id   = aws_api_gateway_rest_api.hello.id
  resource_id   = aws_api_gateway_resource.hello.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_deployment" "hello_v1" {
  depends_on = [
    aws_api_gateway_integration.hello
  ]
  rest_api_id = aws_api_gateway_rest_api.hello.id
  stage_name  = var.environment
}

resource "aws_api_gateway_integration" "hello" {
  rest_api_id             = aws_api_gateway_rest_api.hello.id
  resource_id             = aws_api_gateway_resource.hello.id
  http_method             = aws_api_gateway_method.hello.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello.invoke_arn
}

output "url" {
  value = "${aws_api_gateway_deployment.hello_v1.invoke_url}${aws_api_gateway_resource.hello.path}"
}

resource "aws_api_gateway_base_path_mapping" "endpoint" {
  depends_on = [
    aws_route53_record.endpoint-certificate
  ]

  count = var.domain_name != "" ? 1 : 0

  api_id      = aws_api_gateway_rest_api.hello.id
  stage_name  = aws_api_gateway_deployment.hello_v1.stage_name
  domain_name = "${var.environment}.${var.domain_name}"
}

data "aws_route53_zone" "liftspace" {
  name = "${var.domain_name}."
}

resource "aws_api_gateway_domain_name" "endpoint" {
  certificate_arn = aws_acm_certificate.endpoint-certificate.arn
  domain_name     = aws_acm_certificate.endpoint-certificate.domain_name
  security_policy = "TLS_1_2"
}

resource "aws_route53_record" "endpoint" {
  name    = aws_api_gateway_domain_name.endpoint.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.liftspace.zone_id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.endpoint.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.endpoint.cloudfront_zone_id
  }
}

resource "aws_acm_certificate" "endpoint-certificate" {
  provider = aws.us-east-1

  domain_name       = "${var.environment}.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "endpoint-certificate" {
  provider = aws.us-east-1

  for_each = {
    for dvo in aws_acm_certificate.endpoint-certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records = [
  each.value.record]
  ttl     = 60
  type    = each.value.type
  zone_id = data.aws_route53_zone.liftspace.zone_id
}
