#VPC Deployment
resource "aws_vpc" "workspaces-vpc" {
 cidr_block = "10.0.0.0/16"
 tags = {
   Name = "workspaces-vpc"
   "Deployed By" = "Enkompass"
 }
}

resource "aws_subnet" "public_subnets" {
 count      = length(var.public_subnet_cidrs)
 vpc_id     = aws_vpc.workspaces-vpc.id
 cidr_block = element(var.public_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)

 tags = {
   Name = "Public Subnet ${count.index + 1}"
   "Deployed By" = "Enkompass"
 }
}

resource "aws_subnet" "private_subnets" {
 count      = length(var.private_subnet_cidrs)
 vpc_id     = aws_vpc.workspaces-vpc.id
 cidr_block = element(var.private_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)

 tags = {
   Name = "Private Subnet ${count.index + 1}"
   "Deployed By" = "Enkompass"
 }
}

resource "aws_internet_gateway" "igw" {
 vpc_id = aws_vpc.workspaces-vpc.id
 tags = {
   Name = "Workspaces VPC IGW"
   "Deployed By" = "Enkompass"
 }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "workspaces-nat" {
  vpc = true
  tags = {
    Name = "Workspaces NAT IP"
    "Deployed By" = "Enkompass"
  }
}


# NAT Gateway
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.workspaces-nat.id
  subnet_id = aws_subnet.public_subnets[1].id
  tags = {
    Name = "Workspaces VPC NAT GW"
    "Deployed By" = "Enkompass"
 }
 depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public_rt" {
 vpc_id = aws_vpc.workspaces-vpc.id

 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.igw.id
 }

 tags = {
   Name = "Public Subnets"
   "Deployed By" = "Enkompass"
 }
}

resource "aws_route_table" "private_rt" {
 vpc_id = aws_vpc.workspaces-vpc.id

 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_nat_gateway.natgw.id
 }

 tags = {
   Name = "Public Subnets"
   "Deployed By" = "Enkompass"
 }
}

resource "aws_route_table_association" "public_assoc" {
 count = length(var.public_subnet_cidrs)
 subnet_id = element(aws_subnet.public_subnets[*].id, count.index)
 route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_assoc" {
 count = length(var.public_subnet_cidrs)
 subnet_id = element(aws_subnet.private_subnets[*].id, count.index)
 route_table_id = aws_route_table.private_rt.id
}


# AWS Directory Service Directory
resource "aws_directory_service_directory" "simple_ad_directory" {
  name     = var.domain
  password = var.domain_password
  size     = var.ad_size
  vpc_settings {
    vpc_id = aws_vpc.workspaces-vpc.id
    subnet_ids = [ aws_subnet.private_subnets[1].id, aws_subnet.private_subnets[2].id]
  }
  tags = {
    Name = "SimpleAD"
    Environment = "Production"
    "Deployed By" = "Enkompass"
  }
}

# IAM Trust Relationship
data "aws_iam_policy_document" "workspaces" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["workspaces.amazonaws.com"]
    }
  }
}

# IAM Roles and Policies
resource "aws_iam_role" "workspaces-default" {
  name = "workspaces_DefaultRole"
  assume_role_policy = data.aws_iam_policy_document.workspaces.json
}

resource "aws_iam_role_policy_attachment" "workspaces-default-service-access" {
  role = aws_iam_role.workspaces-default.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonWorkSpacesServiceAccess"
}

resource "aws_iam_role_policy_attachment" "workspaces-default-self-service-access" {
  role = aws_iam_role.workspaces-default.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonWorkSpacesSelfServiceAccess"
}

# Workspaces Directory Attachment
resource "aws_workspaces_directory" "workspaces-directory" {
 directory_id = aws_directory_service_directory.simple_ad_directory.id
  subnet_ids   = [ aws_subnet.private_subnets[1].id, aws_subnet.private_subnets[2].id]
  depends_on = [aws_iam_role.workspaces-default]
}

# Windows Standard Bundle
data "aws_workspaces_bundle" "standard_windows" {
 bundle_id = "wsb-gk1wpk43z"
}

# KMS Key
resource "aws_kms_key" "workspaces-kms" {
  description = "Workspaces KMS"
  deletion_window_in_days = 7
}

# Workspace Deploy
resource "aws_workspaces_workspace" "workspaces" {
  directory_id = aws_workspaces_directory.workspaces-directory.id
  bundle_id = data.aws_workspaces_bundle.standard_windows.id

  # Administrator for SimpleAD
  # Admin for ManagedAD
  user_name = "Administrator"
  root_volume_encryption_enabled = true
  user_volume_encryption_enabled = true
  volume_encryption_key = aws_kms_key.workspaces-kms.arn
  workspace_properties {
    compute_type_name = "STANDARD"
    user_volume_size_gib = 50
    root_volume_size_gib = 80
    running_mode = "ALWAYS_ON"
    running_mode_auto_stop_timeout_in_minutes = 60
  }
  tags = {
    Name = "Setup Workspace"
    Environment = "Production"
    "Deployed By" = "Enkompass"
  }

  depends_on = [
    aws_iam_role.workspaces-default,
    aws_workspaces_directory.workspaces-directory
  ]
}
resource "aws_workspaces_workspace" "daniel" {
  directory_id = aws_workspaces_directory.workspaces-directory.id
  bundle_id = data.aws_workspaces_bundle.standard_windows.id

  # Administrator for SimpleAD
  # Admin for ManagedAD
  user_name = "dlitvin"
  root_volume_encryption_enabled = true
  user_volume_encryption_enabled = true
  volume_encryption_key = aws_kms_key.workspaces-kms.arn
  workspace_properties {
    compute_type_name = "STANDARD"
    user_volume_size_gib = 50
    root_volume_size_gib = 80
    running_mode = "ALWAYS_ON"
    running_mode_auto_stop_timeout_in_minutes = 60
  }
  tags = {
    Name = "Daniel Litvin"
    Environment = "Production"
    "Deployed By" = "Enkompass"
  }

  depends_on = [
    aws_iam_role.workspaces-default,
    aws_workspaces_directory.workspaces-directory
  ]
}
resource "aws_workspaces_workspace" "david" {
  directory_id = aws_workspaces_directory.workspaces-directory.id
  bundle_id = data.aws_workspaces_bundle.standard_windows.id

  # Administrator for SimpleAD
  # Admin for ManagedAD
  user_name = "dmeyer"
  root_volume_encryption_enabled = true
  user_volume_encryption_enabled = true
  volume_encryption_key = aws_kms_key.workspaces-kms.arn
  workspace_properties {
    compute_type_name = "STANDARD"
    user_volume_size_gib = 50
    root_volume_size_gib = 80
    running_mode = "ALWAYS_ON"
    running_mode_auto_stop_timeout_in_minutes = 60
  }
  tags = {
    Name = "David Meyer"
    Environment = "Production"
    "Deployed By" = "Enkompass"
  }

  depends_on = [
    aws_iam_role.workspaces-default,
    aws_workspaces_directory.workspaces-directory
  ]
}
resource "aws_workspaces_workspace" "jason" {
  directory_id = aws_workspaces_directory.workspaces-directory.id
  bundle_id = data.aws_workspaces_bundle.standard_windows.id

  # Administrator for SimpleAD
  # Admin for ManagedAD
  user_name = "jmeyer"
  root_volume_encryption_enabled = true
  user_volume_encryption_enabled = true
  volume_encryption_key = aws_kms_key.workspaces-kms.arn
  workspace_properties {
    compute_type_name = "STANDARD"
    user_volume_size_gib = 50
    root_volume_size_gib = 80
    running_mode = "ALWAYS_ON"
    running_mode_auto_stop_timeout_in_minutes = 60
  }
  tags = {
    Name = "Jason Meyer"
    Environment = "Production"
    "Deployed By" = "Enkompass"
  }

  depends_on = [
    aws_iam_role.workspaces-default,
    aws_workspaces_directory.workspaces-directory
  ]
}

resource "aws_workspaces_workspace" "karam" {
  directory_id = aws_workspaces_directory.workspaces-directory.id
  bundle_id = data.aws_workspaces_bundle.standard_windows.id

  # Administrator for SimpleAD
  # Admin for ManagedAD
  user_name = "kgill"
  root_volume_encryption_enabled = true
  user_volume_encryption_enabled = true
  volume_encryption_key = aws_kms_key.workspaces-kms.arn
  workspace_properties {
    compute_type_name = "STANDARD"
    user_volume_size_gib = 50
    root_volume_size_gib = 80
    running_mode = "ALWAYS_ON"
    running_mode_auto_stop_timeout_in_minutes = 60
  }
  tags = {
    Name = "Karam Gill"
    Environment = "Production"
    "Deployed By" = "Enkompass"
  }

  depends_on = [
    aws_iam_role.workspaces-default,
    aws_workspaces_directory.workspaces-directory
  ]
}
resource "aws_workspaces_workspace" "ray" {
  directory_id = aws_workspaces_directory.workspaces-directory.id
  bundle_id = data.aws_workspaces_bundle.standard_windows.id

  # Administrator for SimpleAD
  # Admin for ManagedAD
  user_name = "rgill"
  root_volume_encryption_enabled = true
  user_volume_encryption_enabled = true
  volume_encryption_key = aws_kms_key.workspaces-kms.arn
  workspace_properties {
    compute_type_name = "STANDARD"
    user_volume_size_gib = 50
    root_volume_size_gib = 80
    running_mode = "ALWAYS_ON"
    running_mode_auto_stop_timeout_in_minutes = 60
  }
  tags = {
    Name = "Ray Gill"
    Environment = "Production"
    "Deployed By" = "Enkompass"
  }

  depends_on = [
    aws_iam_role.workspaces-default,
    aws_workspaces_directory.workspaces-directory
  ]
}
