# Flugel.IT-exam
terraform exam for working purposes
I have merged the tasks 1 and 2 onto a single task.

Task:
Build Terraform code to create an AWS S3 bucket with two files: test1.txt and test2.txt. The content of these files must be the timestamp when the code was executed.
Create a cluster of 2 EC2 instances behind an ALB running Traefik, to serve the files in the S3 bucket.
The cluster must be deployed in a new VPC. This VPC must have only public subnets. Do not use default VPC.
Protect the files in the S3 bucket, so only the EC2 instances using IAM roles can access them.
Using Terratest, create the test automation for the Terraform code, validating that both files and the bucket are created successfully. 
Setup Github Actions to run a pipeline to validate this code.
Publish your code in a public GitHub repository, and share a Pull Request with your code. Do not merge into master until the PR is approved.
Include documentation describing the steps to run and test the automation.
The test must check that files are reachable in the ALB.


This was the initial task:

TEST #1
Create Terraform code to create an AWS S3 bucket with two files: test1.txt and test2.txt. The content of these files must be the timestamp when the code was executed.
Using Terratest, create the test automation for the Terraform code, validating that both files and the bucket are created successfully. 
Setup Github Actions to run a pipeline to validate this code.
Publish your code in a public GitHub repository, and share a Pull Request with your code. Do not merge into master until the PR is approved.
Include documentation describing the steps to run and test the automation.

TEST #2

Complete the test #1 + the following actions:
Merge any pending PR.
Create a new PR with code and updated documentation for the new requirement.
I want a cluster of 2 EC2 instances behind an ALB running Traefik, to serve the files in the S3 bucket.
The cluster must be deployed in a new VPC. This VPC must have only public subnets. Do not use default VPC.
Protect the files in the S3 bucket, so only the EC2 instances using IAM roles can access them.
Update the tests to validate the infrastructure. The test must check that files are reachable in the ALB.
