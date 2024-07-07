provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# EC2 Instance with MongoDB
resource "aws_instance" "mongodb" {
  ami           = "ami-0c55b159cbfafe1f0"  # Update this to the latest Ubuntu 20.04 LTS AMI ID
  instance_type = "t2.micro"
  tags = {
    Name = "MongoDB-Instance"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y mongodb
              systemctl start mongodb
              systemctl enable mongodb

              # Set up backup script
              echo '0 0 * * * /usr/bin/mongodump --out /backup/`date +\\%Y\\%m\\%d` && aws s3 sync /backup s3://mongodb-backup-bucket-${random_string.suffix.result}/' > /etc/cron.d/mongodb-backup
              EOF

  provisioner "file" {
    source      = "~/.ssh/id_rsa.pub"
    destination = "/home/ubuntu/.ssh/authorized_keys"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y mongodb",
      "sudo systemctl start mongodb",
      "sudo systemctl enable mongodb",
      "echo '0 0 * * * /usr/bin/mongodump --out /backup/`date +\\%Y\\%m\\%d` && aws s3 sync /backup s3://mongodb-backup-bucket-${random_string.suffix.result}/' > /etc/cron.d/mongodb-backup"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
}

# S3 Bucket for MongoDB Backups
resource "aws_s3_bucket" "mongodb_backup" {
  bucket = "mongodb-backup-bucket-${random_string.suffix.result}"
  acl    = "public-read"

  tags = {
    Name = "MongoDB Backup Bucket"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

# VPC Configuration
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.78.0"

  name = "example-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  database_subnets = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

  enable_nat_gateway = true
}

# EKS Cluster Configuration
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "example-cluster"
  cluster_version = "1.21"
  subnets         = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  node_groups = {
    eks_nodes = {
      desired_capacity = 2
      max_capacity     = 2
      min_capacity     = 1

      instance_type = "t3.medium"
    }
  }
}

# Deploy WordPress on EKS
resource "kubernetes_deployment" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = "default"
    labels = {
      app = "wordpress"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "wordpress"
      }
    }

    template {
      metadata {
        labels = {
          app = "wordpress"
        }
      }

      spec {
        container {
          name  = "wordpress"
          image = "wordpress:latest"

          ports {
            container_port = 80
          }

          env {
            name  = "WORDPRESS_DB_HOST"
            value = "mongodb.${aws_instance.mongodb.private_ip}"
          }

          env {
            name  = "WORDPRESS_DB_USER"
            value = "root"
          }

          env {
            name  = "WORDPRESS_DB_PASSWORD"
            value = "rootpassword"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = "default"
  }

  spec {
    selector = {
      app = "wordpress"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

# Outputs
output "ec2_instance_public_ip" {
  value = aws_instance.mongodb.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.mongodb_backup.bucket
}

output "wordpress_url" {
  value = kubernetes_service.wordpress.status.load_balancer[0].ingress[0].hostname
}
