#!/bin/bash
echo "successfully started the script" >> bash.log

sleep 180 

echo "successfully exported shared credential file" >> bash.log
export AWS_SHARED_CREDENTIALS_FILE=~/.aws/credentials

echo "successfully exported pcliclient" >> bash.log
export PGCLIENTENCODING=UTF8

echo "connecting to redshift spectrum" >> bash.log
  
psql -f ./redshiftsetup/setup.sql postgres://${redshift_user}:${redshift_password}@${redshift_host}/${redshift_database}

echo "postgres://${redshift_user}:${redshift_password}@${redshift_host}/${redshift_database}" >> bash.log
rm ./redshiftsetup/setup.sql

echo "adding redshift connections to Airflow connection param" >> bash.log
ssh -i ${identityfile} ubuntu@${ec2_dns} "docker exec -d webserver airflow connections add 'redshift' --conn-type 'Postgres' --conn-login ${redshift_user} --conn-password ${redshift_password} --conn-host ${redshift_dns} --conn-port ${redshift_port} --conn-schema 'userpurchase'"

echo "adding postgres connections to Airflow connection param" >> bash.log
ssh -i ${identityfile} ubuntu@${ec2_dns} "docker exec -d webserver airflow connections add 'postgres_default' --conn-type 'Postgres' --conn-login 'airflow' --conn-password 'airflow' --conn-host 'localhost' --conn-port 5432 --conn-schema 'airflow'"

echo "adding S3 bucket name to Airflow variables" >> bash.log
ssh -i ${identityfile} ubuntu@${ec2_dns} "docker exec -d webserver airflow variables set BUCKET ${bucket_name}"

echo "set Airflow AWS region" >> bash.log
ssh -i ${identityfile} ubuntu@${ec2_dns} "docker exec -d webserver airflow connections add 'aws_default' --conn-type 'aws' --conn-extra '{\"region_name\":\"'${aws_region}'\"}'"

echo "adding EMR ID to Airflow variables" >. bash.log
ssh -i ${identityfile} ubuntu@${ec2_dns} "docker exec -d webserver airflow variables set EMR_ID ${emr_cluster_id}"
