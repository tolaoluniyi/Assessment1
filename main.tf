provider "aws" {
  region = "us-east-1" # Replace with your preferred region
}

resource "aws_instance" "mongodb" {
  ami           = "ami-0abcdef1234567890" # Replace with an outdated Linux AMI ID
  instance_type = "t2.micro"
  tags = {
    Name = "MongoDBInstance"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10",
      "echo 'deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse' | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list",
      "sudo apt-get update",
      "sudo apt-get install -y mongodb-org",
      "sudo service mongod start"
    ]

    connection {
      type     = "ssh"
      user     = "ubuntu" # Adjust according to your AMI
      private_key = file("~/Downloads/devopskeypair.pem")
      host     = self.public_ip
    }
  }
}

resource "aws_s3_bucket" "mongodb_backups" {
  bucket = "my-mongodb-backups"

  acl    = "public-read"
  
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-mongodb-backups/*"
    }
  ]
}
POLICY
}
