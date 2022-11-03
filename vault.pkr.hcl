variable "ami_regions" {
  type    = list(string)
  default = [
    "ap-south-1",
    "ap-northeast-1",
    "ap-northeast-2",
    "ap-northeast-3",
    "ap-southeast-1",
    "ap-southeast-2",
    "ca-central-1",
    "eu-central-1",
    "eu-west-1",
    "eu-west-2",
    "eu-west-3",
    "eu-north-1",
    "sa-east-1",
    "us-east-1",
    "us-east-2",
    "us-west-1",
    "us-west-2",
  ]
}

variable "ami_groups" {
  type = list(string)
  default = [
    "all"
  ]
}

variable "builder_region" {
  type    = string
  default = "eu-west-3"
}

variable "builder_subnet_id" {
  type    = string
  default = "subnet-935273fa"
}

variable "builder_vpc_id" {
  type    = string
  default = "vpc-fd794394"
}

variable "vault_version" {
  type    = string
  default = "1.11.5"
}

variable "vault_version_checksum" {
  type    = string
  default = "4f98cbfb105985eeea3057e2fafd34c06638235277d7068e2c34ffde1dc54228"
}

data "amazon-ami" "al2022" {
  filters = {
    name                = "al2022-ami-2022*-x86_64"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
  region      = "${var.builder_region}"
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "amazon-ebs" "ec2-amazonlinux2022" {
  ami_description = "vault-${var.vault_version}-al2002-ami-hvm-x86_64-${local.timestamp}"
  ami_name        = "vault-${var.vault_version}-al2022-ami-hvm-x86_64-${local.timestamp}"
  ami_regions     = var.ami_regions
  ami_groups      = var.ami_groups
  communicator    = "ssh"
  instance_type   = "t3.small"
  region          = "${var.builder_region}"
  run_tags = {
    Name           = "Vault ${var.vault_version} Builder"
    build_date     = "${local.timestamp}"
    packer         = true
    packer_version = "${packer.version}"
  }
  run_volume_tags = {
    Name           = "Vault ${var.vault_version} Builder"
    build_date     = "${local.timestamp}"
    packer         = true
    packer_version = "${packer.version}"
  }
  source_ami   = "${data.amazon-ami.al2022.id}"
  spot_price   = "auto"
  ssh_username = "ec2-user"
  subnet_id    = "${var.builder_subnet_id}"
  tags = {
    Name           = "vault-${var.vault_version}-al2022-ami-hvm-x86_64-${local.timestamp}"
    build_date     = "${local.timestamp}"
    os             = "Amazon Linux 2022"
    packer         = true
    packer_version = "${packer.version}"
    vault_version  = "${var.vault_version}"
  }
  vpc_id = "${var.builder_vpc_id}"
  ssh_interface = "public_dns"
}

build {
  sources = ["source.amazon-ebs.ec2-amazonlinux2022"]
  provisioner "ansible" {
    extra_arguments = ["--extra-vars", "vault_version=${var.vault_version} vault_version_checksum=${var.vault_version_checksum}"]
    playbook_file   = "./ansible/site.yml"
    use_proxy = false
  }
}
