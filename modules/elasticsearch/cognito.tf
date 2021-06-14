# https://medium.com/neiman-marcus-tech/building-a-secure-aws-managed-elasticsearch-cluster-using-terraform-ea876f79d297
# https://gist.github.com/kevin-dsouza/7fbba1565332c96ed665e8d5da9983a1/337ea39e2645190cd0a40a5c33390f4e96e5ffa5

resource "aws_cognito_user_pool" "kibana_user_pool" {
  name = var.name

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = true
  }
}

resource "aws_cognito_identity_pool" "kibana_identity_pool" {
  identity_pool_name               = replace(var.name, "-", "_")
  allow_unauthenticated_identities = false

  lifecycle {
    ignore_changes = [
      # https://github.com/hashicorp/terraform-provider-aws/issues/5557#issuecomment-491477178
      # The Cognito client automatically created by AWS ES is manually configured (see README.md)
      cognito_identity_providers
    ]
  }
}

data "aws_iam_policy_document" "elasticsearch_cognito_trust_policy_doc" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["es.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_cognito_user_pool_domain" "user_pool" {
  domain       = var.name
  user_pool_id = aws_cognito_user_pool.kibana_user_pool.id
}

resource "aws_iam_role" "kibana_cognito_role" {
  name               = "${var.name}-kibana"
  path               = "/terraform/"
  assume_role_policy = data.aws_iam_policy_document.elasticsearch_cognito_trust_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "kibana_cognito_role_policy" {
  role       = aws_iam_role.kibana_cognito_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonESCognitoAccess"
}

data "aws_iam_policy_document" "cognito_auth_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "cognito-sync:*",
      "cognito-identity:*",
      "es:ESHttp*"
    ]
    resources = ["${aws_elasticsearch_domain.es.arn}/*"]
  }
}

data "aws_iam_policy_document" "cognito_auth_trust_relationship_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]
    principals {
      type        = "Federated"
      identifiers = ["cognito-identity.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "cognito-identity.amazonaws.com:aud"

      values = [
        "${aws_cognito_identity_pool.kibana_identity_pool.id}"
      ]
    }
    condition {
      test     = "ForAnyValue:StringLike"
      variable = "cognito-identity.amazonaws.com:amr"

      values = [
        "authenticated"
      ]
    }
  }
}

resource "aws_iam_policy" "cognito_auth_policy" {
  name        = var.name
  path        = "/terraform/"
  description = "Authorization policy for kibana cognito identity pool"

  policy = data.aws_iam_policy_document.cognito_auth_policy_doc.json

}

resource "aws_iam_role" "cognito_auth_role" {
  name = "${var.name}-cognito"
  path = "/terraform/"

  assume_role_policy = data.aws_iam_policy_document.cognito_auth_trust_relationship_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "cognito_auth_role_policy" {
  role       = aws_iam_role.cognito_auth_role.name
  policy_arn = aws_iam_policy.cognito_auth_policy.arn
}

resource "aws_cognito_identity_pool_roles_attachment" "identity_pool" {
  identity_pool_id = aws_cognito_identity_pool.kibana_identity_pool.id

  roles = {
    "authenticated" = aws_iam_role.cognito_auth_role.arn
  }
}
