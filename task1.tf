provider "aws" {
  region = "us-east-1"
  profile = "default"
}

resource "aws_security_group" "task1-sg" {
  name        = "task1-sg"
  description = "allow ssh and http traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


resource "aws_ebs_volume" "ebs1" {
	availability_zone  = "us-east-1a"
	type	   = "gp2"
	size		   = 1
	tags		   = {
		Name = "taskebs"
	}
}



resource "aws_instance" "taskos" {
	ami		   = "ami-09d95fab7fff3776c"
	availability_zone  = "us-east-1a"
	instance_type	   = "t2.micro"
	security_groups	   = ["${aws_security_group.task1-sg.name}"]
        key_name           = "mykey"
	user_data	   = <<-EOF
			       #! /bin/bash
			       sudo su - root
			       yum install httpd -y
			       yum install php -y
			       yum install git -y
			       yum update -y
			       service httpd start
			       chkconfig --add httpd
	EOF
	tags		   = {
		Name = "taskos"
	}
}


resource "aws_volume_attachment" "ebs_att" {
	device_name  = "/dev/sdc"
	volume_id    = "${aws_ebs_volume.ebs1.id}"
	instance_id  = "${aws_instance.taskos.id}"
	force_detach = true
}

resource "null_resource" "format_git" {

	connection {
		type  = "ssh"
		user  = "ec2-user"
		private_key  = file("C:/Users/manan/Downloads/mykey.pem")
		host  = aws_instance.taskos.public_ip
	}
	provisioner "remote-exec" {
		inline = [ 
			     "sudo mkfs -t ext4 /dev/xvdc",
			     "sudo mount /dev/xvdc /var/www/html",
			     "sudo rm -rf /var/www/html/*",
			     "sudo git clone https://github.com/manan2812/HC_task1.git /var/www/html/",
		]
		
	}
	depends_on  = ["aws_volume_attachment.ebs_att"]
}

resource "aws_s3_bucket" "mytaskbucket123" {
    bucket  = "mytaskbucket123"
    region  = "us-east-1"
    acl     = "public-read"
}


resource "aws_s3_bucket_object" "image-upload" {
    bucket  = aws_s3_bucket.mytaskbucket123.bucket
    key     = "myphoto.jpeg"
    source  = "C:/Users/manan/Desktop/dog.jpeg"
    acl     = "public-read"
}

variable "var1" {default = "S3-"}

locals {
    s3_origin_id = "${var.var1}${aws_s3_bucket.mytaskbucket123.bucket}"
    image_url = "${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.image-upload.key}"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
    default_cache_behavior {
        allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = local.s3_origin_id
        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
    }

    enabled             = true

    origin {
        domain_name = aws_s3_bucket.mytaskbucket123.bucket_domain_name
        origin_id   = local.s3_origin_id
    }

    restrictions {
        geo_restriction {
        restriction_type = "none"
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }

    connection {
        type    = "ssh"
        user    = "ec2-user"
        host    = aws_instance.taskos.public_ip
        port    = 22
        private_key  = file("C:/Users/manan/Downloads/mykey.pem")
    }

    provisioner "remote-exec" {
        inline  = [
            # "sudo su << \"EOF\" \n echo \"<img src='${self.domain_name}'>\" >> /var/www/html/test.html \n \"EOF\""
            "sudo su << EOF",
            "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.image-upload.key}'>\" >> /var/www/html/test.html",
            "EOF"
        ]
    }
}

