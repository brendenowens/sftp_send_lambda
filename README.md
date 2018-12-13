# sftp_send_lambda
This is a lambda function script for sending files out of S3 using SFTP. This script was to help make up for what AWS Transfer for SFTP didn't do. 

## Architecture
The design for this lambda function is very simple. You have an S3 bucket that you drop files into and those files need to be sent to either a vendor or some sort of SFTP server. Once a file is dropped into the S3 bucket a trigger fires off a lambda function that is using the code found in this repo. The lambda function will then process the event and send the file using SFTP to the destination. The process ends up looking like this:

S3 -> Put Event -> Lambda Execution -> File Delivered

## Setup
In order to get this process working you will need to get a few things in order first.
1. The pair of SSH keys, public and private, used to transfer the file to the server
2. The SNS topic arn you want to send notifications to about a this certain file transfer
3. An IAM Role for the Lambda function to assume and that has access to your S3 bucket/s

### About the Config file
In this repo you get the skeleton of the config file that this lambda script uses. I will explain what the individual fields are and their purpose in the script. These should be in JSON format with key value pairs. 

**secret_name** is the name of the AWS Secrets Manager secret that this script should pull the SSH keys from so that it can authenticate with the server and send your files
**hostname** is the name or IP of the server that you will be sending your file to. For example if I am sending a file to *google.com*, then I would put *google.com* as the **hostname** in the config.
**username** is the username that the script should use when it tries to authenticate with the server. So if my username on *google.com* was *evee* then I would put *evee* as the username in the config.
**topic** is the ARN, Amazon Resource Number, of the SNS topic that you will be sending notifications to.
**destination** is the path on the destination server that the file should be sent to. For example */final/destination/* would be what you would put as the value. *Note: You should end your path with a / otherwise you might put the file in the wrong directory.*

### About the SSH Key in AWS Secrets Manager
When putting in your SSH keys into AWS Secrets Manager, make sure that all newlines are replaced with *\n*. This will cause you to get errors that say the format of the key is not correct or doesn't begin with what an SSH key should. 


                