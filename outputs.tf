output "dev_ip" {
  value = aws_instance.dev_node.public_ip
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "redshift_host" {
  value = aws_redshift_cluster.redshift_cluster.endpoint
}

output "emr_cluster_id" {
  value = aws_emr_cluster.emr_cluster.id
}

output "public_ip" {
  value = data.http.my_local_ip.response_body
}