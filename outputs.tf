output "instance_public_ip" {
  value = aws_instance.mongodb.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.mongodb_backups.bucket
}
