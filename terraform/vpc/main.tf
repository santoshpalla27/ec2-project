resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-vpc"
    }
  )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-igw"
    }
  )
}

resource "aws_subnet" "public_subnet" {
  count = length(var.public_subnets)
  vpc_id = aws_vpc.main.id
  cidr_block = var.public_subnets[count.index]
  availability_zone = data.aws_availability_zones.az.names[count.index  % length(data.aws_availability_zones.az.names)]
  map_public_ip_on_launch = true
  tags = merge(
    var.tags,var.public_subnets_tags,
    {
      Name = "${var.vpc_name}-public-subnet-${count.index}"
    }
  )
}


resource "aws_subnet" "private_subnet" {
  count = length(var.private_subnets)
  vpc_id = aws_vpc.main.id
  cidr_block = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.az.names[count.index  % length(data.aws_availability_zones.az.names)]
  tags = merge(
    var.tags,var.private_subnets_tags,
    {
      Name = "${var.vpc_name}-private-subnet-${count.index}"
    }
  )
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat_eip" {
  count  = var.create_nat_gateway ? (var.single_nat_gateway ? 1 : min(length(var.public_subnets), length(data.aws_availability_zones.az.names))) : 0
  domain = "vpc"
  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-nat-eip-${count.index}"
    }
  )
  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count         = var.create_nat_gateway ? (var.single_nat_gateway ? 1 : min(length(var.public_subnets), length(data.aws_availability_zones.az.names))) : 0
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public_subnet[count.index].id
  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-nat-gateway-${count.index}"
    }
  )
  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-public-route-table"
    }
  )
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

# Private Route Tables (one per AZ if multiple NAT gateways, otherwise just one)
resource "aws_route_table" "private" {
  count  = var.create_nat_gateway ? ( var.single_nat_gateway ? 1 : min(length(var.public_subnets), length(data.aws_availability_zones.az.names)) ) : 1
  vpc_id = aws_vpc.main.id
  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-private-route-table-${count.index}"
    }
  )
  dynamic "route" {
    for_each = var.create_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
    }
  }
}


resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)
  subnet_id = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public.id
}


resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)
  subnet_id = aws_subnet.private_subnet[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index % length(aws_route_table.private)].id
}

