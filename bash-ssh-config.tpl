#!/bin/bash
echo "Adding host to ssh config file" >> bash.log
cat << EOF >> ~/.ssh/config
Host ${hostname}
    HostName ${hostname}
    User ${user}
    IdentityFile ${identityfile}
EOF

echo "Running setup script on redshift" >> bash.log
echo "CREATE EXTERNAL SCHEMA spectrum
FROM DATA CATALOG DATABASE 'spectrumdb' iam_role 'arn:aws:iam::"${account_id}":role/"${iam_role_name}"' CREATE EXTERNAL DATABASE IF NOT EXISTS;
DROP TABLE IF EXISTS spectrum.user_purchase_staging;
CREATE EXTERNAL TABLE spectrum.user_purchase_staging (
    InvoiceNo VARCHAR(10),
    StockCode VARCHAR(20),
    detail VARCHAR(1000),
    Quantity INTEGER,
    InvoiceDate TIMESTAMP,
    UnitPrice DECIMAL(8, 3),
    customerid INTEGER,
    Country VARCHAR(20)
) PARTITIONED BY (insert_date DATE) 
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' 
STORED AS textfile 
LOCATION 's3://"${bucket_name}"/stage/user_purchase/' 
TABLE PROPERTIES ('skip.header.line.count' = '1');
DROP TABLE IF EXISTS spectrum.classified_movie_review;
CREATE EXTERNAL TABLE spectrum.classified_movie_review (
    cid VARCHAR(100),
    positive_review boolean,
    insert_date VARCHAR(12)
) STORED AS PARQUET LOCATION 's3://"${bucket_name}"/stage/movie_review/';
DROP TABLE IF EXISTS public.user_behavior_metric;
CREATE TABLE public.user_behavior_metric (
    customerid INTEGER,
    amount_spent DECIMAL(18, 5),
    review_score INTEGER,
    review_count INTEGER,
    insert_date DATE
);" > ./redshiftsetup/setup.sql

sleep 5

echo "SCP to copy code to remote server" >> bash.log
cd ../
scp -i ${identityfile} -r ./beginner_pipeline/code ubuntu@${ec2_dns}:/home/ubuntu/Aws_pipeline
cd beginner_pipeline

echo "Download Data" >> bash.log
ssh -i ${identityfile} ubuntu@${ec2_dns} 'cd Aws_pipeline && wget https://start-data-engg.s3.amazonaws.com/data.zip && sudo apt install zip unzip && sudo unzip data.zip && sudo chmod 755 data'

echo "Recreate logs and temp dir" >> bash.log
ssh -i ${identityfile} ubuntu@${ec2_dns} 'cd Aws_pipeline && rm -rf logs && mkdir logs && rm -rf temp && mkdir temp && chmod 777 temp'

echo "Spinning up remote Airflow docker containers" >> bash.log
ssh -i ${identityfile} ubuntu@${ec2_dns} 'cd Aws_pipeline && echo -e "AIRFLOW_UID=$(id -u)\nAIRFLOW_GID=0" > .env && docker-compose up airflow-init && docker-compose up --build -d'

echo "Sleeping 5 Minutes to let Airflow containers reach a healthy state" >> bash.log
sleep 300


