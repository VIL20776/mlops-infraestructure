data "archive_file" "training_lambda_file" {
  type        = "zip"
  source_file = "${path.module}/lambda/create_training.py"
  output_path = "${path.module}/lambda/function.zip"
}

resource "aws_lambda_function" "training_lambda" {
  filename      = data.archive_file.training_lambda_file.output_path
  function_name = "create_training_instance"
  role          = aws_iam_role.lambda_role.arn
  handler       = "create_training.lambda_handler"
  code_sha256   = data.archive_file.training_lambda_file.output_base64sha256
  runtime       = "python3.12"

  environment {
    variables = {
      AWS_REGION          = data.aws_region.current.region
      DATA_BUCKET_NAME    = aws_s3_bucket.data_storage.bucket
      ECR_REGISTRY        = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com"
      MLFLOW_TRACKING_URI = "http://${aws_instance.mlflow_server.private_ip}:5000"
      SECURITY_GROUP_ID   = aws_security_group.ec2_security_groups["Training"].id
      SUBNET_ID           = aws_subnet.private_subnets["private_3"].id
    }
  }
}
