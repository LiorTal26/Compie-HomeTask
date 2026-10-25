resource "aws_dynamodb_table" "items" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"
  attribute {
    name = "pk"
    type = "S"
  }
  attribute {
    name = "sk"
    type = "S"
  }
  server_side_encryption {
    enabled = true # AWS-managed aws/dynamodb key, rather than the default AWS-owned key.
  }
}
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect    = "Allow", Principal = "*",
      Action    = ["dynamodb:Query", "dynamodb:PutItem", "dynamodb:DeleteItem"],
      Resource  = aws_dynamodb_table.items.arn,
      Condition = { ArnEquals = { "aws:PrincipalArn" = local.app_role_arn } }
    }]
  })
  tags = { Name = "${local.prefix}-dynamodb" }
}
resource "aws_dynamodb_resource_policy" "items" {
  resource_arn = aws_dynamodb_table.items.arn
  policy = jsonencode({
    Version = "2012-10-17", Statement = [
      {
        Sid       = "DataOnlyThroughPrivateEndpoint", Effect = "Deny", Principal = "*",
        Action    = local.data_actions, Resource = aws_dynamodb_table.items.arn,
        Condition = { StringNotEquals = { "aws:SourceVpce" = aws_vpc_endpoint.dynamodb.id } }
      },
      {
        Sid       = "DataOnlyForApplicationRole", Effect = "Deny", Principal = "*",
        Action    = local.data_actions, Resource = aws_dynamodb_table.items.arn,
        Condition = { ArnNotEquals = { "aws:PrincipalArn" = local.app_role_arn } }
      }
    ]
  })
}
