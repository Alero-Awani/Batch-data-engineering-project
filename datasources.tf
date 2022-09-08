# TO GET THE EC2 INSTANCE AMI
data "aws_ami" "server_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

#TO GET THE ACCOUNT ID 
data "aws_caller_identity" "current" {}

#TO GET YOUR PUBLIC IP ADDRESS
data "http" "my_local_ip" {
  url = "https://ipv4.icanhazip.com"
}