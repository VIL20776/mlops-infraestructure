resource "aws_key_pair" "ssh_access" {
  key_name   = "ssh_access"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2UxPqDer4l9mvhyN9s8tlJrwUAPZu79zglt9pxpWstqHytWYItMNmYnXpkKtVytAj4sYIsqNkPV/8K/wmK7265WZH7ZolDHaOCaQSZpsfz0BmI/HfVc+07LGf8sMlsPXZCAp9HDAysxzl7ADiAlC4UkW4WVz+s6UDiNtiRTs+qZ3iE5VU6H8Gt8omkiNYAe7pRVz4/8b5g9/MAIE3cjnIwKmsEQ7aPKkuGAWYc1xpAyEeZIiXkfj65TgIAH+xf4v9Ix7LrdYQCjEt8GXk1+rWavbxYuRe3pTMFsPKFYsoz0cOyM6lfqYXT8jf4VjaJnENxFjugwjdivjgt2u3DGG7"
}

data "aws_ami" "ubuntu_server" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

# data "aws_ami" "ubuntu-dl" {
#   most_recent = true
#
#   filter {
#     name   = "name"
#     values = ["Deep Learning OSS Nvidia Driver AMI GPU PyTorch 2.10 (Ubuntu 24.04) *"]
#   }
#
#   owners = ["898082745236"]
# }

resource "aws_instance" "mlflow_server" {
  ami                    = data.aws_ami.ubuntu_server.id
  instance_type          = "t3.medium"
  iam_instance_profile   = aws_iam_instance_profile.ec2_profiles["MLFlow"].name
  vpc_security_group_ids = [aws_security_group.ec2_security_groups["MLFlow"].id]
  subnet_id              = aws_subnet.public_subnets["public_1"].id
  key_name               = aws_key_pair.ssh_access.key_name
  user_data = templatefile("./scripts/mlflow-setup.sh", {
    s3_bucket   = aws_s3_bucket.artifact_storage.bucket
    db_user     = aws_db_instance.tracking_database.username
    db_passwd   = aws_db_instance.tracking_database.password
    db_endpoint = aws_db_instance.tracking_database.endpoint
    db_name     = aws_db_instance.tracking_database.db_name
  })
  user_data_replace_on_change = true
  depends_on = [
    aws_db_instance.tracking_database,
    aws_s3_bucket.artifact_storage
  ]

  tags = {
    Name = "mlflow_server"
  }
}

resource "aws_instance" "deployment_server" {
  count                  = var.deploy ? 1 : 0
  ami                    = data.aws_ami.ubuntu_server.id
  instance_type          = "t3.medium"
  iam_instance_profile   = aws_iam_instance_profile.ec2_profiles["Deployment"].name
  vpc_security_group_ids = [aws_security_group.ec2_security_groups["Deployment"].id]
  subnet_id              = aws_subnet.public_subnets["public_1"].id
  key_name               = aws_key_pair.ssh_access.key_name
  user_data = templatefile("./scripts/deploy-setup.sh", {
    aws_region     = data.aws_region.current.region
    ecr_repository = aws_ecr_repository.deployment_repo.repository_url
    s3_bucket      = aws_s3_bucket.model_storage.bucket
    sqs_queue_url  = aws_sqs_queue.pull_release_queue.url
    releases_dir   = "/var/local/models"
  })
  user_data_replace_on_change = true
  depends_on = [
    aws_ecr_repository.deployment_repo,
    aws_s3_bucket.model_storage
  ]

  root_block_device {
    volume_size = 16
  }

  tags = {
    Name = "deployment_server"
  }
}
