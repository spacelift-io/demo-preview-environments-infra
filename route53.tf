resource "aws_api_gateway_domain_name" "endpoint" {
  certificate_arn = var.certificate_arn
  domain_name     = local.endpoint
  security_policy = "TLS_1_2"
}

resource "aws_route53_record" "endpoint" {
  provider = aws.us-east-1

  name    = aws_api_gateway_domain_name.endpoint.domain_name
  type    = "A"
  zone_id = var.domain_name_zone_id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.endpoint.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.endpoint.cloudfront_zone_id
  }
}
