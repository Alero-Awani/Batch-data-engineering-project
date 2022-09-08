variable "host_os" {
  type        = string
  description = "specify the intepreter for the local-exec file"
}
variable "bucket_name" {
  description = "Name of the s3 bucket"
}

variable "rs_cluster_identifier" {
  description = "The name of the redshift cluster"
}

variable "rs_master_username" {
  description = "This is the redshift cluster username for login"
}

variable "rs_master_pass" {
  description = "This is the redshift cluster password for login"
}

variable "rs_nodetype" {
  description = "The node type to be provisioned for the redshift cluster e.g dc2.large"
}

variable "rs_cluster_type" {
  description = "The redshift cluster type to use. Either single-node or multi-node"
}

variable "rs_port" {
  description = "The port number on which the cluster accepts incoming connections.Valid values are between 1115 and 65535. Default port is 5439"
}

variable "aws_region" {
  description = "Region selected to provision resources e.g us-east-1"
}

variable "redshift_role_name" {
  description = "IAM role for the redshift cluster"
}

variable "rs_database_name" {
  description = "The name of the first database to be created when the cluster is created. If you do not provide a name,Amazon Redshift will create a default database called dev"
}

# EMR VARIABLES 

variable "applications" {
  description = "Name of the applications to be installed"
  type        = list(string)
}
variable "emr_name" {
  description = "Name of the EMR cluster"
}

variable "release_label" {
  description = "Release label for the Amazon EMR release e.g emr-6.2.0"
}

variable "master_instance_group_name" {
  description = "Name of the Master instance group"
}

variable "master_instance_group_instance_type" {
  description = "EC2 instance type for all instances in the master instance group.e.g m4.large"
}

variable "master_instance_group_instance_count" {
  description = "Target number of instances for the master instance group. Must be at least 1. Defaults to 1"
}

variable "master_instance_group_ebs_size" {
  description = "EBS volume size for master instance group"
}

variable "master_instance_group_ebs_type" {
  description = "EBS Volume type for master instance group, e.g gp3, gp2"
}

variable "master_instance_group_ebs_volumes_per_instance" {
  description = "Number of EBS volumes with this configuration to attach to each EC2 instance in the master instance group (default is 1)"
}

variable "core_instance_group_name" {
  description = "Name of the core instance group"
}

variable "core_instance_group_instance_type" {
  description = "EC2 instance type for all instances in the core instance group.e.g m4.large"
}

variable "core_instance_group_instance_count" {
  description = "Target number of instances for the core instance group. Must be at least 1. Defaults to 1"
}

variable "core_instance_group_ebs_size" {
  description = "EBS volume size for core instance group"
}

variable "core_instance_group_ebs_type" {
  description = "EBS Volume type for core instance group, e.g gp3, gp2"
}

variable "core_instance_group_ebs_volumes_per_instance" {
  description = "Number of EBS volumes with this configuration to attach to each EC2 instance in the core instance group (default is 1)"
}