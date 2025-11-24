# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Axon Runtime Route Table (VPC Endpoints only, with NAT fallback)
resource "aws_route_table" "axon_runtime" {
  vpc_id = aws_vpc.main.id

  # Route to NAT Gateway as fallback (if VPC endpoints fail or for debugging)
  # Note: VPC endpoints work via DNS, but NAT provides backup connectivity
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id # Use first NAT Gateway
  }

  tags = {
    Name = "${var.project_name}-axon-runtime-rt"
  }
}

resource "aws_route_table_association" "axon_runtime" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.axon_runtime[count.index].id
  route_table_id = aws_route_table.axon_runtime.id
}

