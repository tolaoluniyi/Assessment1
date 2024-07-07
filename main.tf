
#MongoDB EC2 Instance Creation

provider "aws" {
  region = "us-east-1"
  profile = "default"
}

resource "aws_instance" "mongodb" {
  ami           = "ami-0c55b159cbfafe1f0"  # Example for Ubuntu 16.04
  instance_type = "t2.micro"
  tags = {
    Name = "MongoDB-Instance"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y mongodb
              systemctl start mongodb
              systemctl enable mongodb
              EOF

  provisioner "file" {
    source      = "~/.ssh/id_rsa.pub"
    destination = "/home/ubuntu/.ssh/authorized_keys"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y mongodb",
      "sudo systemctl start mongodb",
      "sudo systemctl enable mongodb"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/Downloads/devopskeypair.pem")
      host        = self.public_ip
    }
  }
}

#S3 Bucket with permissions set to allow public read access
resource "aws_s3_bucket" "mongodb_backup" {
  bucket = "mongodb-backup-bucket"
  acl    = "public-read"
}

#EKS CLuster
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.78.0"

  name = "example-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  database_subnets = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

  enable_nat_gateway = true
}

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
