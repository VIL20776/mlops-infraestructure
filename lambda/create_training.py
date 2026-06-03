import boto3
import os

ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    subnet_id = os.getenv('SUBNET_ID')
    security_group_id = os.getenv('SECURITY_GROUP_ID')
    ecr_repo_url = f"{os.getenv('ECR_REGISTRY')}/training/{event.get('project_id')}"
    user_data = f"""#!/bin/bash
        wget https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
        sudo dpkg -i -E ./amazon-cloudwatch-agent.deb

        cat << EOF > /opt/aws/amazon-cloudwatch-agent/bin/config.json
{{
  "logs": {{
    "logs_collected": {{
      "files": {{
        "collect_list": [
          {{
            "file_path": "/var/log/cloud-init.log",
            "log_group_name": "/ec2/user-data",
            "log_stream_name": "{event.get('project_id')}"
          }},
          {{
            "file_path": "/var/log/cloud-init-output.log",
            "log_group_name": "/ec2/user-data",
            "log_stream_name": "{event.get('project_id')}-output"
          }}
        ]
      }}
    }}
  }}
}}
EOF

        /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
            -a fetch-config \
            -m ec2 \
            -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json \
            -s

        apt update
        apt install docker.io -y
        snap install aws-cli --classic
        aws ecr get-login-password --region {os.getenv('AWS_REGION')} | \
        docker login --username AWS --password-stdin {ecr_repo_url}

        docker pull {ecr_repo_url}:latest

        docker run \
        -e MLFLOW_TRACKING_URI={os.getenv('MLFLOW_TRACKING_URI')} \
        -e DATA_BUCKET_NAME={os.getenv('DATA_BUCKET_NAME')} \
        -e MLFLOW_EXPERIMENT_NAME={event.get('project_id')} \
        {ecr_repo_url}:latest \
        python train.py
        shutdown -h +1
        """

    response = ec2.run_instances(
        ImageId='ami-0eab37cfdc33e8e65', #Ubuntu 24.04 server
        InstanceType='t3.medium',
        MinCount=1,
        MaxCount=1,
        SubnetId=subnet_id,
        SecurityGroupIds=[security_group_id],
        IamInstanceProfile={
            'Name': 'TrainingProfile'
        },
        BlockDeviceMappings=[{
            'DeviceName': '/dev/sda1',
            'Ebs': { 'VolumeSize': 64, 'VolumeType': 'standard' }
        }],
        UserData=user_data,
        TagSpecifications=[{
            'ResourceType': 'instance',
            'Tags': [
                {'Key': 'Name', 'Value': 'ml-training-job'},
                {'Key': 'Project', 'Value': event.get('project_id')}
            ]
        }]
    )

    return {
        'statusCode': 200,
        'instance_id': response['Instances'][0]['InstanceId']
    }
