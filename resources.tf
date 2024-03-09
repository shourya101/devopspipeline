resource "aws_vpc" "myvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "mygfgvpc"
  }
}
resource "aws_subnet" "mygfgsubnet" {
  vpc_id     = aws_vpc.myvpc.id #argument refrencing
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "gfgsubnetpublic"
  }
}

resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "myigw"
  }
}

resource "aws_route_table" "myrt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id
  }

  tags = {
    Name = "mygfgroutetable"
  }
}


resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.mygfgsubnet.id
  route_table_id = aws_route_table.myrt.id
}

resource "aws_instance" "mygfgweb" {
  ami           = data.aws_ami.latest_amazon_linux.id
  instance_type = var.instanceType
  subnet_id   = aws_subnet.mygfgsubnet.id
  tags = {
    Name = "${var.instanceTagName}-${count.index}"
  }
  key_name = var.keyname
  vpc_security_group_ids = [aws_security_group.webserver_sg.id]
  depends_on = [aws_key_pair.mykey]
  count= 1
  provisioner "local-exec" {
    command = "echo 'resource exectued succesfully'"
  }
}

resource "aws_key_pair" "mykey" {
  key_name   = var.keyname
  public_key = file("mykey.pub")
}

resource "aws_security_group" "webserver_sg" {
  name        = var.sg_name
  description = "Webserver Security Group Allow port 80"
  vpc_id      = aws_vpc.myvpc.id

  dynamic "ingress" {
    for_each = [80,22,8080,3000,9090]
    content { 
    description      = "---"
    from_port        = ingress.value
    to_port          = ingress.value
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "null_resource" "configureAnsibleInventory" {
triggers ={
  mytrigger = timestamp()
}
provisioner "local-exec" {
    command = "echo [prod] > inventory"
  }

}
resource "null_resource" "configureansibleinventoryIPdetails"{
triggers ={
  mytrigger = timestamp()
}
provisioner "local-exec" {
    command = "echo ${aws_instance.mygfgweb.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=mykey >> inventory"
  }
}

resource "null_resource" "destroy_resource"{
  provisioner "local-exec" {
    when = destroy
    command = "echo destroying resources.. > gfgdestroy.txt"
  }
}
