# ============================================================================
# Grupo Hospitalario SanaVI - Autenticación OAuth2/JWT (Cognito) & API Gateway
# Protección de Tráfico Entrante desde Frontends Web y App Móvil
# ============================================================================

resource "aws_cognito_user_pool" "sanavi_user_pool" {
  name = "sanavi-hipaa-user-pool"

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_client" "sanavi_oauth_client" {
  name                                 = "sanavi-web-mobile-oauth-client"
  user_pool_id                         = aws_cognito_user_pool.sanavi_user_pool.id
  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]
  callback_urls                        = ["https://portal.sanavi.cl/callback", "sanaviapp://callback"]
}

resource "aws_apigatewayv2_api" "sanavi_http_api" {
  name          = "sanavi-hospital-api-gateway"
  protocol_type = "HTTP"
  description   = "API Gateway Central de SanaVI con validación OAuth2/JWT y TLS 1.3"

  cors_configuration {
    allow_origins = ["https://portal.sanavi.cl", "https://admin.sanavi.cl"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Authorization", "Content-Type", "X-Amz-Trace-Id"]
  }
}

resource "aws_apigatewayv2_authorizer" "cognito_jwt" {
  api_id           = aws_apigatewayv2_api.sanavi_http_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "sanavi-cognito-jwt-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.sanavi_oauth_client.id]
    issuer   = "https://${aws_cognito_user_pool.sanavi_user_pool.endpoint}"
  }
}
