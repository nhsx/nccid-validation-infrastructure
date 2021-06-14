output "elasticsearch-endpoint" {
  value = aws_elasticsearch_domain.es.endpoint
}

output "kibana-endpoint" {
  value = aws_elasticsearch_domain.es.kibana_endpoint
}

output "lambda-admin-role" {
  value = aws_iam_role.es-admin-lambda-role.arn
}
