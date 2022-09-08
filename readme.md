# Batch-Data-Engineering-Project
The task is to build a data pipeline to populate the user_behavior_metric table. The user_behavior_metric table is an OLAP table, meant to be used by analysts, 
dashboard software, etc. It is built from user_purchase, an OLTP table with user purchase information and movie_review.csv, data sent every day by an external data vendor.
![Project Table](https://github.com/Alero-Awani/Batch-data-engineering-project/blob/master/images/de_proj_obj.png?raw=true)

# REFERENCE
https://www.startdataengineering.com/post/data-engineering-project-for-beginners-batch-edition/

# Architecture
![Pipeline Architecture](https://github.com/Alero-Awani/Batch-data-engineering-project/blob/master/images/de_proj_design.png?raw=true)

# Table of contents
1. [Pipeline Workflow](#Pipeline)
2. [Terraform setup](#Terraform)
3. [Airflow/Airflow Configurations](#Airflow)


## Pipeline Workflow <a name="Pipeline"></a>
### User Purchase Data
* The user purchase data is extracted from an OLTP database and loaded into the Redshift data warehouse.
* AWS S3 is used as storage for use with AWS Redshift Spectrum(data lakehouse)
* With Redshift Spectrum the data can be queried directly from s3 on Redshift by creating an external schema with the help of AWS Glue.

### Movie Review Data
* The movie review data is loaded into a staging area in an s3 bucket  where it can be directly accessed by AWS EMR.
* The data is loaded along side a spark script
* The spark script performs basic text classification on the data and loads it back to the s3 bucket

### User Behaviour Metric Table
* The transformed movie review data and the user_purchase data are joined in Redshift to get the user_behaviour metric table

## Terraform setup <a name="Terraform"></a>
![Terraform Plan](https://github.com/Alero-Awani/Batch-data-engineering-project/blob/master/images/terraform_visual.png?raw=true)

### overview
* This pipeline requires us to setup Apache Airflow, AWS EMR,AWS Redshift, AWS Spectrum, and AWS S3, AWS EC2.
* The EC2 instance and has docker and docker-compose installed on it through the use of user-data.tpl, This helps in setting up the Airflow with the docker-compose yaml file
* The yaml file also contains a Postgres container and a metabase container for visualization

### Setting up Infrastructure
Generate a key pair
```
ssh-keygen -t ed25519
```
Prepare the working directory
```
terraform init
```
To Preview the changes terraform plans to make to your infrastructure.
```
terraform plan
```
To execute the actions proposed in the terraform plan and create the resources.
```
terraform apply
```
To terminate the resources.
```
terraform destroy
```




## Airflow/Airflow Configurations <a name="Airflow"></a>
![Airflow Dag](https://github.com/Alero-Awani/Batch-data-engineering-project/blob/master/images/Airflow%20dag.png?raw=true)











