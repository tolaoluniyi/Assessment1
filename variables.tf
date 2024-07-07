variable "aws_region" {
  description = "The AWS region to deploy in"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instance"
  default     = "ami-0abcdef1234567890" # Replace with an outdated Linux AMI ID
}
