#select provider
provider "aws" {
  access_key = "ACCESS_KEY_HERE"
  secret_key = "SECRET_KEY_HERE"
  region     = "us-east-1"
}

#add random var str
resource "random_string" "bucket_suffix" {
  length  = 4
  special = false
}
# Create S3 bucket 
resource "aws_s3_bucket" "my_bucket" {
  bucket = "S3Test-${random_string.bucket_suffix.result}" #randomness made
  acl    = "private"
  #versioning enabled
  versioning {
    enabled = true
  }
  #add flavour tags
  tags = {
    Name = my_bucket.id
    Environment = "Test"
    Owner       = "Eze Iglesias"
  }
  #make it encrypted
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# Create S3 bucket objects
resource "aws_s3_bucket_object" "test1_txt" {
  bucket = aws_s3_bucket.my_bucket.id
  key    = "test1.txt"
  content = timestamp()
}

resource "aws_s3_bucket_object" "test2_txt" {
  bucket = aws_s3_bucket.my_bucket.id
  key    = "test2.txt"
  content = timestamp()
}

#Create a new VPC resource with public subnets and an internet gateway
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

  #create 2 public subnets and an internet gateway
resource "aws_subnet" "public_subnet_a" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

  #add IGW
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

  #add IGW route tables to VPC
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

  #create  public subnets assosiations
resource "aws_route_table_association" "public_subnet_a_association" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.my_route_table.id
}

resource "aws_route_table_association" "public_subnet_b_association" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.my_route_table.id
}

#Create a security group resource for the EC2 instances to allow traffic from the ALB and between instances
resource "aws_security_group" "my_security_group" {
  name_prefix = "my_security_group"

  #inet
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  #ssh
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
   }

  #allow incoming ICMP echo from any source via a security group (value 8 should work)
  ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    #allow 8080  
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  #outgoing traffic from instances unrestricted
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  }

  #create load balancer add both subnets and SGs
resource "aws_lb" "my_lb" {
name = "my-lb"
internal = false
load_balancer_type = "application"
security_groups = [aws_security_group.my_security_group.id]
subnets = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
tags = {
Name = "my-lb"
}
}

  #create an ALB target group and listener
resource "aws_lb_target_group" "my_target_group" {
name_prefix = "my-target-group"
port = 80
protocol = "HTTP"
vpc_id = aws_vpc.my_vpc.id
target_type = "instance"
health_check_path = "/"

depends_on = [aws_lb.my_lb]
}

  #listens
resource "aws_lb_listener" "my_listener" {
load_balancer_arn = aws_lb.my_lb.arn
port = "80"
protocol = "HTTP"
  
  #alb target group
default_action {
target_group_arn = aws_lb_target_group.my_target_group.arn
type = "forward"
}

depends_on = [aws_lb.my_lb, aws_lb_target_group.my_target_group]
}


# Create IAM role for EC2 instances to access S3 bucket
resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Create IAM policy to grant S3 bucket access to EC2 instances
resource "aws_iam_policy" "s3_policy" {
  name        = "s3_policy"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource  = [
          aws_s3_bucket.my_bucket.arn,
          "${aws_s3_bucket.my_bucket.arn}/*",
        ]
      }
    ]
  })
}

# Attach IAM policy to IAM role
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  policy_arn = aws_iam_policy.s3_policy.arn
  role       = aws_iam_role.ec2_role.name
}

resource "aws_launch_template" "traefik_instance_template" {
  name_prefix   = "traefik_instance_template_"
  instance_type = "t2.micro"
  image_id      = data.aws_ami.ubuntu.id
  
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io
              docker run -d -p 80:80 -p 8080:8080 -v /var/run/docker.sock:/var/run/docker.sock traefik:v2.5
              EOF
}
security_groups = [aws_security_group.my_security_group.id]
user_data = <<-EOF
#!/bin/bash
echo 'AccessKey=ACCESS_KEY_HERE' >> /etc/traefik/traefik.env
echo 'SecretKey=SECRET_KEY_HERE' >> /etc/traefik/traefik.env
echo 'Bucket=my-unique-bucket-name' >> /etc/traefik/traefik.env
systemctl start traefik
EOF

 #configure it to use the S3 bucket created in Test1
provisioner "remote-exec" {
    inline = [
      "echo 'aws s3 sync s3://${aws_s3_bucket.my_bucket.id} /usr/share/nginx/html' > /tmp/sync.sh", 
      "chmod +x /tmp/sync.sh",
      "sh /tmp/sync.sh",
      "docker network create traefik-net",
      "docker run -d -p 80:80 -p 8080:8080 --name traefik -v /var/run/docker.sock:/var/run/docker.sock -v /opt/traefik:/etc/traefik --network traefik-net traefik:v2.5 --configFile=/etc/traefik/traefik.yml",
    ]
  }

#scale it to2
resource "aws_autoscaling_group" "my_autoscaling_group" {
launch_configuration = aws_launch_configuration.my_launch_configuration.id
desired_capacity = 2
max_size = 2
min_size = 2

target_group_arns = [aws_lb_target_group.my_target_group.arn]

vpc_zone_identifier = [
aws_subnet.public_subnet_a.id,
aws_subnet.public_subnet_b.id,
]
tag {
key = "Name"
role = aws_iam_role.ec2_role.name
value = "traefik-instance"
propagate_at_launch = true
}
}
