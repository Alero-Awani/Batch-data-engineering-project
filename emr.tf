#CREATE VPC
resource "aws_vpc" "emr_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "emr_vpc"
  }
}

# CREATE A PUBLIC SUBNET IN THE VPC
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.emr_vpc.id
  cidr_block              = "10.123.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "emr_public_subnet"
  }
}

#CREATE AN INTERNET GATEWAY
resource "aws_internet_gateway" "my_gateway" {
  vpc_id = aws_vpc.emr_vpc.id

  tags = {
    Name = "my_gateway"
  }
}

# CREATE A ROUTE TABLE 
resource "aws_route_table" "public_routing_table" {
  vpc_id = aws_vpc.emr_vpc.id
  tags = {
    Name = "public_routing_table"
  }
}

# CREATE A ROUTE 
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public_routing_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_gateway.id
}


#CREATE ROUTE TABLE ASSOCIATION 
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_routing_table.id
}

#CREATE AN IAM ROLE FOR THE CLUSTER
resource "aws_iam_role" "emr_service_role" {
  name = "emr_service_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }
      },
    ]
  })

}

#CREATE IAM ROLE FOR THE EMR PROFILE 
resource "aws_iam_role" "emr_profile_role" {
  name = "emr_profile_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}


#ATTACH THE POLICY TO THE EMR CLUSTER/EMR SERVICE ROLE
resource "aws_iam_role_policy_attachment" "attach_emr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
  role       = aws_iam_role.emr_service_role.name
}

#ATTACH THE POLICY TO THE EMR CLUSTER/EMR PROFILE ROLE
resource "aws_iam_role_policy_attachment" "attach_emr_profile_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
  role       = aws_iam_role.emr_profile_role.name
}

# CREATE THE INSTANCE PROFILE TO PASS THE ROLE DETAILS TO THE EC2 INSTANCES
resource "aws_iam_instance_profile" "emr_profile" {
  name = "spark_cluster_emr_profile"
  role = aws_iam_role.emr_profile_role.name
}

#CREATE SECURITY GROUP FOR MASTER NODE 
resource "aws_security_group" "master_security_group" {
  name        = "master_security_group"
  description = "Allow inbound traffic from VPN"
  vpc_id      = aws_vpc.emr_vpc.id

  # Avoid circular dependencies stopping the destruction of the cluster
  revoke_rules_on_delete = true

  # Allow communication between nodes in the VPC
  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port = "8443"
    to_port   = "8443"
    protocol  = "TCP"
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH traffic from VPN
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${chomp(data.http.my_local_ip.body)}/32"]
  }

  #### Expose web interfaces to VPN

  # Spark History
  ingress {
    from_port   = 18080
    to_port     = 18080
    protocol    = "TCP"
    cidr_blocks = ["123.123.0.0/16"]
  }

  # Spark UI
  ingress {
    from_port   = 4040
    to_port     = 4040
    protocol    = "TCP"
    cidr_blocks = ["123.123.0.0/16"]
  }

  tags = {
    name = "emr_master_security_group"
  }
}

# CREATE SECURITY GROUP FOR CORE NODE
resource "aws_security_group" "slave_security_group" {
  name                   = "slave_security_group"
  description            = "Allow all internal traffic"
  vpc_id                 = aws_vpc.emr_vpc.id
  revoke_rules_on_delete = true

  # Allow communication between nodes in the VPC
  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port = "8443"
    to_port   = "8443"
    protocol  = "TCP"
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH traffic from VPN
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${chomp(data.http.my_local_ip.body)}/32"]
  }

  tags = {
    name = "emr_slave_security_group"
  }
}


#CREATE THE EMR CLUSTER
resource "aws_emr_cluster" "emr_cluster" {
  name                   = var.emr_name
  release_label          = var.release_label
  applications           = var.applications
  termination_protection = false
  service_role           = aws_iam_role.emr_service_role.arn

  ec2_attributes {
    key_name                          = aws_key_pair.mtc_auth.id
    subnet_id                         = aws_subnet.public_subnet.id
    emr_managed_master_security_group = aws_security_group.master_security_group.id
    emr_managed_slave_security_group  = aws_security_group.slave_security_group.id
    instance_profile                  = aws_iam_instance_profile.emr_profile.arn
  }

  master_instance_group {
    name           = var.master_instance_group_name
    instance_type  = var.master_instance_group_instance_type
    instance_count = var.master_instance_group_instance_count
    ebs_config {
      size                 = var.master_instance_group_ebs_size
      type                 = var.master_instance_group_ebs_type
      volumes_per_instance = var.master_instance_group_ebs_volumes_per_instance
    }
  }

  core_instance_group {
    name           = var.core_instance_group_name
    instance_type  = var.core_instance_group_instance_type
    instance_count = var.core_instance_group_instance_count
    ebs_config {
      size                 = var.core_instance_group_ebs_size
      type                 = var.core_instance_group_ebs_type
      volumes_per_instance = var.core_instance_group_ebs_volumes_per_instance
    }
  }

  tags = {
    Name        = var.emr_name
    Project     = "emr_spark_job"
    Environment = "dev"
    role        = "EMR_DefaultRole"

  }
  depends_on = [
    aws_iam_role_policy_attachment.attach_emr_profile_policy,
    aws_iam_role_policy_attachment.attach_emr_policy,
    aws_iam_instance_profile.emr_profile,
    null_resource.provisioner_resource
  ]
}
