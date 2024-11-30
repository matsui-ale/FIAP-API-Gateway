# Provider Configuration
provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "terraform-tfstate-grupo12-fiap-2024"
    key    = "api_gateway/terraform.tfstate"
    region = "us-east-1"
  }
}

#Buscando as Lambdas
data "aws_lambda_function" "lambda_pedido" {
  function_name = "lambda_pedido_function"
}

data "aws_lambda_function" "lambda_produto" {
  function_name = "lambda_produto_function"
}

data "aws_lambda_function" "lambda_pagamento" {
  function_name = "lambda_pagamento_function"
}

data "aws_lambda_function" "lambda_cliente" {
  function_name = "lambda_cliente_function"
}

# API Gateway Authorizer
resource "aws_api_gateway_authorizer" "lambda_authorizer" {
  rest_api_id                      = aws_api_gateway_rest_api.lanchonete_api.id
  name                             = "LambdaAuthorizer"
  type                             = "REQUEST"
  authorizer_uri                   = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.lambda_authorizer.arn}/invocations"
  identity_source                  = "method.request.header.cpf" # Define a fonte de identidade como o cabeçalho 'cpf'
  authorizer_result_ttl_in_seconds = 0                           # Desativa o cache
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "lanchonete_api" {
  name        = "LanchoneteAPI"
  description = "API Gateway para Lanchonete - Micros Serviços"
}

# Resources under "/api"
resource "aws_api_gateway_resource" "cliente_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_rest_api.lanchonete_api.root_resource_id
  path_part   = "Cliente"
}

resource "aws_api_gateway_resource" "pedido_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_rest_api.lanchonete_api.root_resource_id
  path_part   = "Pedido"
}

resource "aws_api_gateway_resource" "produto_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_rest_api.lanchonete_api.root_resource_id
  path_part   = "Produto"
}

# Sub-resources under "/api/Cliente"
resource "aws_api_gateway_resource" "cliente_cpf_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_resource.cliente_resource.id
  path_part   = "{cpf}"
}

# Sub-resources under "/api/Pedido"
resource "aws_api_gateway_resource" "pedido_id_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_resource.pedido_resource.id
  path_part   = "{id}"
}

resource "aws_api_gateway_resource" "pedido_filtrados_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_resource.pedido_resource.id
  path_part   = "Filtrados"
}

resource "aws_api_gateway_resource" "pedido_status_pagamento_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_resource.pedido_resource.id
  path_part   = "StatusPagamento"
}

resource "aws_api_gateway_resource" "pedido_status_pagamento_id_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_resource.pedido_status_pagamento_resource.id
  path_part   = "{id}"
}

resource "aws_api_gateway_resource" "pedido_status_pedido_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_resource.pedido_resource.id
  path_part   = "StatusPedido"
}

# Sub-resources under "/api/Produto"
resource "aws_api_gateway_resource" "produto_categoria_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_resource.produto_resource.id
  path_part   = "{categoria}"
}

# Methods and Integrations for Each Endpoint

### /Cliente/{cpf} - GET ###
resource "aws_api_gateway_method" "get_cliente_by_cpf" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.cliente_cpf_resource.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id
  request_parameters = {
    "method.request.path.cpf" = true
  }
}

resource "aws_api_gateway_integration" "get_cliente_by_cpf_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id             = aws_api_gateway_resource.cliente_cpf_resource.id
  http_method             = aws_api_gateway_method.get_cliente_by_cpf.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${data.aws_lambda_function.lambda_cliente.arn}/invocations"

  request_parameters = {
    "integration.request.path.cpf" = "method.request.path.cpf"
  }
}

### /Cliente - POST ###
resource "aws_api_gateway_method" "post_cliente" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.cliente_resource.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id
  request_models = {
    "application/json" = aws_api_gateway_model.CriarClienteRequest.name
  }
}

resource "aws_api_gateway_integration" "post_cliente_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id             = aws_api_gateway_resource.cliente_resource.id
  http_method             = aws_api_gateway_method.post_cliente.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${data.aws_lambda_function.lambda_cliente.arn}/invocations"
}

### /Pedido - GET & POST ###
resource "aws_api_gateway_method" "get_pedido" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.pedido_resource.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id
}

resource "aws_api_gateway_integration" "get_pedido_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id             = aws_api_gateway_resource.pedido_resource.id
  http_method             = aws_api_gateway_method.get_pedido.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${data.aws_lambda_function.lambda_pedido.arn}/invocations"
}

resource "aws_api_gateway_method" "post_pedido" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.pedido_resource.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id
  request_models = {
    "application/json" = aws_api_gateway_model.CriarPedidoRequest.name
  }
}

resource "aws_api_gateway_integration" "post_pedido_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id             = aws_api_gateway_resource.pedido_resource.id
  http_method             = aws_api_gateway_method.post_pedido.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${data.aws_lambda_function.lambda_pedido.arn}/invocations"
}

### /Pedido/{Id} - GET ###
resource "aws_api_gateway_method" "get_pedido_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.pedido_id_resource.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id
  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "get_pedido_by_id_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id             = aws_api_gateway_resource.pedido_id_resource.id
  http_method             = aws_api_gateway_method.get_pedido_by_id.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${data.aws_lambda_function.lambda_pedido.arn}/invocations"

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
}

### /Pedido/Filtrados - GET ###
resource "aws_api_gateway_method" "get_pedido_filtrados" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.pedido_filtrados_resource.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id
}

resource "aws_api_gateway_integration" "get_pedido_filtrados_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id             = aws_api_gateway_resource.pedido_filtrados_resource.id
  http_method             = aws_api_gateway_method.get_pedido_filtrados.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${data.aws_lambda_function.lambda_pedido.arn}/invocations"
}

### /Pedido/StatusPagamento/{Id} - GET ###
resource "aws_api_gateway_method" "get_status_pagamento_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.pedido_status_pagamento_id_resource.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id
  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "get_status_pagamento_by_id_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id             = aws_api_gateway_resource.pedido_status_pagamento_id_resource.id
  http_method             = aws_api_gateway_method.get_status_pagamento_by_id.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${data.aws_lambda_function.lambda_pedido.arn}/invocations"

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
}

### /Pedido/StatusPedido - PUT ###
resource "aws_api_gateway_method" "put_status_pedido" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.pedido_status_pedido_resource.id
  http_method   = "PUT"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id
  request_models = {
    "application/json" = aws_api_gateway_model.AtualizarStatusPedidoRequest.name
  }
}

resource "aws_api_gateway_integration" "put_status_pedido_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id             = aws_api_gateway_resource.pedido_status_pedido_resource.id
  http_method             = aws_api_gateway_method.put_status_pedido.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${data.aws_lambda_function.lambda_pedido.arn}/invocations"
}

### /Pedido/StatusPagamento - PUT ###
resource "aws_api_gateway_method" "put_status_pagamento" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.pedido_status_pagamento_resource.id
  http_method   = "PUT"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id
  request_models = {
    "application/json" = aws_api_gateway_model.AtualizarStatusPagamentoRequest.name
  }
}

resource "aws_api_gateway_integration" "put_status_pagamento_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id             = aws_api_gateway_resource.pedido_status_pagamento_resource.id
  http_method             = aws_api_gateway_method.put_status_pagamento.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${data.aws_lambda_function.lambda_pedido.arn}/invocations"
}

### /Produto/{categoria} - GET ###
resource "aws_api_gateway_method" "get_produto_by_categoria" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.produto_categoria_resource.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id
  request_parameters = {
    "method.request.path.categoria" = true
  }
}

resource "aws_api_gateway_integration" "get_produto_by_categoria_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id             = aws_api_gateway_resource.produto_categoria_resource.id
  http_method             = aws_api_gateway_method.get_produto_by_categoria.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${data.aws_lambda_function.lambda_produto.arn}/invocations"

  request_parameters = {
    "integration.request.path.categoria" = "method.request.path.categoria"
  }
}

### /Produto - POST, PUT, DELETE ###
resource "aws_api_gateway_method" "post_produto" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.produto_resource.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id
  request_models = {
    "application/json" = aws_api_gateway_model.CriarProdutoRequest.name
  }
}

resource "aws_api_gateway_integration" "post_produto_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id             = aws_api_gateway_resource.produto_resource.id
  http_method             = aws_api_gateway_method.post_produto.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${data.aws_lambda_function.lambda_produto.arn}/invocations"
}

resource "aws_api_gateway_method" "put_produto" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.produto_resource.id
  http_method   = "PUT"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id
  request_models = {
    "application/json" = aws_api_gateway_model.AtualizarProdutoRequest.name
  }
}

resource "aws_api_gateway_integration" "put_produto_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id             = aws_api_gateway_resource.produto_resource.id
  http_method             = aws_api_gateway_method.put_produto.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${data.aws_lambda_function.lambda_produto.arn}/invocations"
}

resource "aws_api_gateway_method" "delete_produto" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.produto_resource.id
  http_method   = "DELETE"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id
  request_parameters = {
    "method.request.querystring.id" = false
  }
}

resource "aws_api_gateway_integration" "delete_produto_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id             = aws_api_gateway_resource.produto_resource.id
  http_method             = aws_api_gateway_method.delete_produto.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${data.aws_lambda_function.lambda_produto.arn}/invocations"

  request_parameters = {
    "integration.request.querystring.id" = "method.request.querystring.id"
  }
}

#Permission for lambdas

#/Pedido
resource "aws_lambda_permission" "allow_api_gateway_invoke_pedido" {
  statement_id  = "AllowAPIGatewayInvokePedido"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.lambda_pedido.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.lanchonete_api.execution_arn}/*/GET/Pedido"
}

resource "aws_lambda_permission" "allow_api_gateway_invoke_pedido_id" {
  statement_id  = "AllowAPIGatewayInvokePedidoId"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.lambda_pedido.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.lanchonete_api.execution_arn}/*/GET/Pedido/{id}"
}

resource "aws_lambda_permission" "allow_api_gateway_invoke_pedido_filtrados" {
  statement_id  = "AllowAPIGatewayInvokePedidoFiltrados"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.lambda_pedido.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.lanchonete_api.execution_arn}/*/GET/Pedido/Filtrados"
}

resource "aws_lambda_permission" "allow_api_gateway_invoke_pedido_statuspagamento" {
  statement_id  = "AllowAPIGatewayInvokePedidoStatusPag"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.lambda_pedido.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.lanchonete_api.execution_arn}/*/GET/Pedido/StatusPagamento/{id}"
}

resource "aws_lambda_permission" "allow_api_gateway_invoke_pedido_post" {
  statement_id  = "AllowAPIGatewayInvokePedidoPost"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.lambda_pedido.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.lanchonete_api.execution_arn}/*/POST/Pedido"
}

resource "aws_lambda_permission" "allow_api_gateway_invoke_pedido_statuspedido" {
  statement_id  = "AllowAPIGatewayInvokePedidoStatusPed"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.lambda_pedido.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.lanchonete_api.execution_arn}/*/PUT/Pedido/StatusPedido"
}

resource "aws_lambda_permission" "allow_api_gateway_invoke_produto" {
  statement_id  = "AllowAPIGatewayInvokeProduto"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.lambda_produto.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.lanchonete_api.execution_arn}/*"
}

resource "aws_lambda_permission" "allow_api_gateway_invoke_cliente" {
  statement_id  = "AllowAPIGatewayInvokeCliente"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.lambda_cliente.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.lanchonete_api.execution_arn}/*"
}

# Define Models for Request Bodies
resource "aws_api_gateway_model" "AtualizarProdutoRequest" {
  rest_api_id  = aws_api_gateway_rest_api.lanchonete_api.id
  name         = "AtualizarProdutoRequest"
  content_type = "application/json"
  schema       = <<EOF
{
  "title": "AtualizarProdutoRequest",
  "type": "object",
  "properties": {
    "id": { "type": "integer" },
    "nome": { "type": "string", "minLength": 1 },
    "descricao": { "type": "string", "minLength": 1 },
    "valor": { "type": "number" },
    "nomeCategoria": { "type": "string", "minLength": 1 }
  },
  "required": ["id", "nome", "descricao", "valor", "nomeCategoria"],
  "additionalProperties": false
}
EOF
}

resource "aws_api_gateway_model" "AtualizarStatusPagamentoRequest" {
  rest_api_id  = aws_api_gateway_rest_api.lanchonete_api.id
  name         = "AtualizarStatusPagamentoRequest"
  content_type = "application/json"
  schema       = <<EOF
{
  "title": "AtualizarStatusPagamentoRequest",
  "type": "object",
  "properties": {
    "PedidoId": { "type": "integer" },
    "statusPagamento": { "type": "integer", "enum": [0, 1, 2] }
  },
  "required": ["PedidoId", "statusPagamento"],
  "additionalProperties": false
}
EOF
}

resource "aws_api_gateway_model" "AtualizarStatusPedidoRequest" {
  rest_api_id  = aws_api_gateway_rest_api.lanchonete_api.id
  name         = "AtualizarStatusPedidoRequest"
  content_type = "application/json"
  schema       = <<EOF
{
  "title": "AtualizarStatusPedidoRequest",
  "type": "object",
  "properties": {
    "id": { "type": "integer" },
    "statusPedido": { "type": "integer", "enum": [1, 2, 3, 4] }
  },
  "required": ["id", "statusPedido"],
  "additionalProperties": false
}
EOF
}

resource "aws_api_gateway_model" "CriarClienteRequest" {
  rest_api_id  = aws_api_gateway_rest_api.lanchonete_api.id
  name         = "CriarClienteRequest"
  content_type = "application/json"
  schema       = <<EOF
{
  "title": "CriarClienteRequest",
  "type": "object",
  "properties": {
    "nome": { "type": "string", "minLength": 1 },
    "cpf": { "type": ["string", "null"] },
    "email": { "type": ["string", "null"] }
  },
  "required": ["nome"],
  "additionalProperties": false
}
EOF
}

resource "aws_api_gateway_model" "CriarPedidoRequest" {
  rest_api_id  = aws_api_gateway_rest_api.lanchonete_api.id
  name         = "CriarPedidoRequest"
  content_type = "application/json"
  schema       = <<EOF
{
  "title": "CriarPedidoRequest",
  "type": "object",
  "properties": {
    "cpf": { "type": ["string", "null"] },
    "produtoQuantidades": {
      "type": "array",
      "items": {
        "$ref": "#/definitions/ProdutoQuantidade"
      }
    },
    "idFormaPagamento": { "type": "integer" }
  },
  "required": ["produtoQuantidades", "idFormaPagamento"],
  "additionalProperties": false,
  "definitions": {
    "ProdutoQuantidade": {
      "type": "object",
      "properties": {
        "idProduto": { "type": "integer" },
        "quantidade": { "type": "integer" }
      },
      "additionalProperties": false
    }
  }
}
EOF
}

resource "aws_api_gateway_model" "CriarProdutoRequest" {
  rest_api_id  = aws_api_gateway_rest_api.lanchonete_api.id
  name         = "CriarProdutoRequest"
  content_type = "application/json"
  schema       = <<EOF
{
  "title": "CriarProdutoRequest",
  "type": "object",
  "properties": {
    "nome": { "type": "string", "minLength": 1 },
    "descricao": { "type": "string", "minLength": 1 },
    "valor": { "type": "number" },
    "nomeCategoria": { "type": "string", "minLength": 1 }
  },
  "required": ["nome", "descricao", "valor", "nomeCategoria"],
  "additionalProperties": false
}
EOF
}

# Deploy the API
resource "aws_api_gateway_deployment" "lanchonete_deployment" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  stage_name  = "Prod"

  depends_on = [
    aws_api_gateway_integration.get_cliente_by_cpf_integration,
    aws_api_gateway_integration.post_cliente_integration,
    aws_api_gateway_integration.get_pedido_integration,
    aws_api_gateway_integration.post_pedido_integration,
    aws_api_gateway_integration.get_pedido_by_id_integration,
    aws_api_gateway_integration.get_pedido_filtrados_integration,
    aws_api_gateway_integration.get_status_pagamento_by_id_integration,
    aws_api_gateway_integration.put_status_pedido_integration,
    aws_api_gateway_integration.put_status_pagamento_integration,
    aws_api_gateway_integration.get_produto_by_categoria_integration,
    aws_api_gateway_integration.post_produto_integration,
    aws_api_gateway_integration.put_produto_integration,
    aws_api_gateway_integration.delete_produto_integration
  ]
}

# Output the API Gateway URL
output "api_gateway_url" {
  description = "URL do API Gateway"
  value       = "${aws_api_gateway_deployment.lanchonete_deployment.invoke_url}/api/"
}