# CREATE S3 BUCKET 
resource "aws_s3_bucket" "etl_bucket" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Name = "etl_bucket"
  }
}

# ADD ACL TO THE S3 BUCKET
resource "aws_s3_bucket_acl" "awsbucketeer_bucket_acl" {
  bucket = aws_s3_bucket.etl_bucket.bucket
  acl    = "public-read-write"
}


# CREATE AWS IAM ROLE FOR EC2_S3_ACCESS
resource "aws_iam_role" "ec2_s3_role" {
  name = "ec2_s3_role"

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

# CREATE AWS IAM ROLE FOR REDSHIFT
resource "aws_iam_role" "redshift_role" {
  name = "redshift_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      },
    ]
  })
}


# ATTACH REQUIRED POLICIES TO THE EC2 IAM ROLE

resource "aws_iam_role_policy_attachment" "attach_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.ec2_s3_role.name
}

resource "aws_iam_role_policy_attachment" "attach_policy_2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRedshiftAllCommandsFullAccess"
  role       = aws_iam_role.ec2_s3_role.name
}
resource "aws_iam_role_policy_attachment" "attach_policy_3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEMRFullAccessPolicy_v2"
  role       = aws_iam_role.ec2_s3_role.name
}

# CREATE INSTANCE PROFILE AND ATTACH IAM ROLE TO IT 
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_s3_role.name
}

# ATTACH REQUIRED POLICIES TO THE REDSHIFT IAM ROLE 
resource "aws_iam_role_policy_attachment" "attach_policy_4" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role       = aws_iam_role.redshift_role.name
}

resource "aws_iam_role_policy_attachment" "attach_policy_5" {
  policy_arn = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"
  role       = aws_iam_role.redshift_role.name
}

# CREATE KEY PAIR
resource "aws_key_pair" "mtc_auth" {
  key_name   = "mtc_key"
  public_key = file("~/.ssh/mtckey.pub")
}


# CREATE SECURITY GROUP
resource "aws_security_group" "mtc_sg" {
  name        = "dev_sg"
  description = "dev security group"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${chomp(data.http.my_local_ip.body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

#CREATE REDSHIFT SECURITY GROUP
resource "aws_security_group" "redshift_security_group" {
  name        = "redshift_sg"
  description = "redshift security group"

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}


# CREATE AWS INSTANCE
resource "aws_instance" "dev_node" {
  instance_type          = "t2.medium"
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  ami                    = data.aws_ami.server_ami.id
  vpc_security_group_ids = [aws_security_group.mtc_sg.id]
  key_name               = aws_key_pair.mtc_auth.id
  user_data              = file("user-data.tpl")

  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = "dev-node"
  }

}

# CREATE TIME_SLEEP RESOURCE TO LET THE EC2 INSTANCE FINISH INITIALIZING
resource "time_sleep" "wait_180_seconds" {
  depends_on      = [aws_instance.dev_node]
  create_duration = "180s"
}

# CREATE NULL RESOURCE TO EXECUTE BASH SCRIPT
resource "null_resource" "provisioner_resource" {
  depends_on = [time_sleep.wait_180_seconds]
  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname      = aws_instance.dev_node.public_ip,
      user          = "ubuntu",
      identityfile  = "~/.ssh/mtckey"
      ec2_dns       = aws_instance.dev_node.public_dns
      account_id    = data.aws_caller_identity.current.account_id
      iam_role_name = var.redshift_role_name
      bucket_name   = var.bucket_name
    })
    interpreter = var.host_os == "bash" ? ["bash", "-c"] : ["powershell", "-command"]
  }

}


# CREATE REDSHIFT NULL RESOURCE
resource "null_resource" "redshift_provisioner_resource" {
  provisioner "local-exec" {
    command = templatefile("redshift-ssh-config.tpl", {
      identityfile      = "~/.ssh/mtckey"
      ec2_dns           = aws_instance.dev_node.public_dns
      redshift_user     = var.rs_master_username
      redshift_password = var.rs_master_pass
      redshift_host     = aws_redshift_cluster.redshift_cluster.endpoint
      redshift_dns      = aws_redshift_cluster.redshift_cluster.dns_name
      redshift_database = var.rs_database_name
      redshift_port     = var.rs_port
      bucket_name       = var.bucket_name
      aws_region        = var.aws_region
      emr_cluster_id    = aws_emr_cluster.emr_cluster.id

      depends_on = [
        aws_redshift_cluster.redshift_cluster
      ]

    })
    interpreter = var.host_os == "bash" ? ["bash", "-c"] : ["powershell", "-command"]
  }

}



# CREATE REDSHIFT CLUSTER RESOURCE
resource "aws_redshift_cluster" "redshift_cluster" {
  cluster_identifier     = var.rs_cluster_identifier
  master_username        = var.rs_master_username
  master_password        = var.rs_master_pass
  node_type              = var.rs_nodetype
  cluster_type           = var.rs_cluster_type
  port                   = var.rs_port
  database_name          = var.rs_database_name
  skip_final_snapshot    = true
  publicly_accessible    = true
  iam_roles              = ["${aws_iam_role.redshift_role.arn}"]
  vpc_security_group_ids = [aws_security_group.redshift_security_group.id]

  depends_on = [
    aws_security_group.redshift_security_group,
    aws_iam_role.redshift_role,
    aws_instance.dev_node,
    null_resource.provisioner_resource,
    aws_emr_cluster.emr_cluster

  ]
}

