variable "name" { type = string }
variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = { Name = var.name }
}
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.name}-igw" }
}
resource "aws_subnet" "public" {
  count = 2
  vpc_id = aws_vpc.this.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.azs[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "${var.name}-public-${count.index + 1}" }
}
resource "aws_subnet" "app" {
  count = 2
  vpc_id = aws_vpc.this.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.azs[count.index]
  tags = { Name = "${var.name}-app-${count.index + 1}" }
}
resource "aws_subnet" "db" {
  count = 2
  vpc_id = aws_vpc.this.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = var.azs[count.index]
  tags = { Name = "${var.name}-db-${count.index + 1}" }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route { cidr_block = "0.0.0.0/0" gateway_id = aws_internet_gateway.this.id }
  tags = { Name = "${var.name}-public" }
}
resource "aws_route_table_association" "public" {
  count = 2
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_eip" "nat" {
  count = 2
  domain = "vpc"
  depends_on = [aws_internet_gateway.this]
}
resource "aws_nat_gateway" "this" {
  count = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id = aws_subnet.public[count.index].id
  tags = { Name = "${var.name}-nat-${count.index + 1}" }
  depends_on = [aws_internet_gateway.this]
}
resource "aws_route_table" "app" {
  count = 2
  vpc_id = aws_vpc.this.id
  route { cidr_block = "0.0.0.0/0" nat_gateway_id = aws_nat_gateway.this[count.index].id }
  tags = { Name = "${var.name}-app-${count.index + 1}" }
}
resource "aws_route_table_association" "app" {
  count = 2
  subnet_id = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.name}-db-isolated" }
}
resource "aws_route_table_association" "db" {
  count = 2
  subnet_id = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}
output "vpc_id" { value = aws_vpc.this.id }
output "public_subnets" { value = aws_subnet.public[*].id }
output "app_subnets" { value = aws_subnet.app[*].id }
output "db_subnets" { value = aws_subnet.db[*].id }
