# https://medium.com/neiman-marcus-tech/building-a-secure-aws-managed-elasticsearch-cluster-using-terraform-ea876f79d297
# https://gist.github.com/kevin-dsouza/8c2c7c9962385a77f9f5f910701892d6/e62efac836bce0297c1bfba66b072943a36920e2

resource "aws_elasticsearch_domain" "es" {
  domain_name           = var.name
  elasticsearch_version = "7.10"

  cluster_config {
    instance_type = "r4.large.elasticsearch"
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 250
  }

  encrypt_at_rest {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  node_to_node_encryption {
    enabled = true
  }

  # vpc_options {
  #   subnet_ids         = var.subnets
  #   security_group_ids = [aws_security_group.es.id]
  # }

  # log_publishing_options {
  #   log_type                 = "SEARCH_SLOW_LOGS"
  #   cloudwatch_log_group_arn = aws_cloudwatch_log_group.es_slow_logs.arn
  #   enabled                  = "true"
  # }

  # log_publishing_options {
  #   log_type                 = "INDEX_SLOW_LOGS"
  #   cloudwatch_log_group_arn = aws_cloudwatch_log_group.es_index_logs.arn
  #   enabled                  = "true"
  # }

  # log_publishing_options {
  #   log_type                 = "ES_APPLICATION_LOGS"
  #   cloudwatch_log_group_arn = aws_cloudwatch_log_group.es_app_logs.arn
  #   enabled                  = "true"
  # }

  cognito_options {
    enabled          = true
    user_pool_id     = aws_cognito_user_pool.kibana_user_pool.id
    identity_pool_id = aws_cognito_identity_pool.kibana_identity_pool.id
    role_arn         = aws_iam_role.kibana_cognito_role.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.kibana_cognito_role_policy
  ]
}

resource "aws_elasticsearch_domain_policy" "es-policy" {
  domain_name     = aws_elasticsearch_domain.es.domain_name
  access_policies = data.aws_iam_policy_document.es-access-policy-doc.json
}

data "aws_iam_policy_document" "es-access-policy-doc" {
  statement {
    effect  = "Allow"
    actions = ["es:*"]
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.cognito_auth_role.arn,
        aws_iam_role.kibana_cognito_role.arn
      ]
    }
    resources = ["${aws_elasticsearch_domain.es.arn}/*"]
  }
}

data "aws_iam_policy_document" "es-admin-lambda-policy-doc" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "es-admin-policy-doc" {
  statement {
    actions   = ["es:*"]
    effect    = "Allow"
    resources = ["${aws_elasticsearch_domain.es.arn}/*"]
  }
}

resource "aws_iam_role" "es-admin-lambda-role" {
  name        = "${var.name}-es-admin-lambda-role"
  path        = "/terraform/"
  description = "AWS lambda access to ElasticSearch"

  assume_role_policy = data.aws_iam_policy_document.es-admin-lambda-policy-doc.json
  inline_policy {
    name   = "${var.name}-es-admin-lambda-policy"
    policy = data.aws_iam_policy_document.es-admin-policy-doc.json
  }
}
