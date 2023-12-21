#Create a VPC
#CIDR BLock range is taken from variables
resource "aws_vpc" "myvpc" {
    cidr_block = var.cidr
  
}

#Create Subnet-I
resource "aws_subnet" "sub1" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
  
}

#Create Subnet-II
resource "aws_subnet" "sub2" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
  
}

#Create Internet Gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.myvpc.id
  
}

#Create Route Table
resource "aws_route_table" "rt" {
    vpc_id = aws_vpc.myvpc.id

    route{
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id

    }
  
}

#Associate Route Table to Subnet-I
resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.sub1.id
    route_table_id = aws_route_table.rt.id
  
}

#Associate Route Table to Subnet-II
resource "aws_route_table_association" "rta2" {
    subnet_id = aws_subnet.sub2.id
    route_table_id = aws_route_table.rt.id
  
}

#Create a Security Group
resource "aws_security_group" "wbsg" {
  name        = "websg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Web-sg"
  }

  
}

#Create a S3 Bucket
resource "aws_s3_bucket" "name" {
    bucket = "terrapr0ject"
  
}

#Create a EC2 First Instance
#User data is taken from userdata.sh file in directory
resource "aws_instance" "terrainstance1" {
    ami = "ami-0c7217cdde317cfec"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.wbsg.id]
    subnet_id = aws_subnet.sub1.id
    user_data = base64encode(file("userdata.sh"))
  
}

# Create a EC2 Second Instance
#User data is taken from userdata1.sh file in directory
resource "aws_instance" "terrainstance2" {
    ami = "ami-0c7217cdde317cfec"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.wbsg.id]
    subnet_id = aws_subnet.sub2.id
    user_data = base64encode(file("userdata1.sh"))
  
}

#Created an ALB
resource "aws_lb" "myalb" {
    name = "myalb"
    internal = false
    load_balancer_type = "application"

    security_groups = [aws_security_group.wbsg.id]
    subnets = [aws_subnet.sub1.id, aws_subnet.sub2.id]

    tags = {
      Name="weeb"
    }
  
}

#Providing ALB Target to VPC
resource "aws_lb_target_group" "tg" {
    name = "mytg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.myvpc.id

    health_check {
      path = "/"
      port = "traffic-port"
    }  
}

#Attaching ALB to Instance 1
resource "aws_lb_target_group_attachment" "attach1" {
    target_group_arn = aws_lb_target_group.tg.arn
    target_id = aws_instance.terrainstance1.id
    port = 80
  
}

#Attaching ALB to Instance 2
resource "aws_lb_target_group_attachment" "attach2" {
    target_group_arn = aws_lb_target_group.tg.arn
    target_id = aws_instance.terrainstance2.id
    port = 80
  
}

#Creating Listner
resource "aws_lb_listener" "listner" {
    load_balancer_arn = aws_lb.myalb.arn
    port = 80
    protocol = "HTTP"

    default_action {
      target_group_arn = aws_lb_target_group.tg.arn
      type = "forward"
    }
  
}

output "loadbalancerdns" {
    value = aws_lb.myalb.dns_name
  
}