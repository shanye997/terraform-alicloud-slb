#############################################################
# create VPC, vswitch and security group
#############################################################
resource "alicloud_vpc" "default" {
  vpc_name   = "tf_module"
  cidr_block = "172.16.0.0/12"
}

resource "alicloud_vswitch" "default" {
  vpc_id     = alicloud_vpc.default.id
  cidr_block = "172.16.0.0/21"
  zone_id    = data.alicloud_zones.default.zones[0].id
}

module "security_group" {
  source  = "alibaba/security-group/alicloud"
  version = "~> 2.0"

  vpc_id = alicloud_vpc.default.id
}

data "alicloud_zones" "default" {
}

data "alicloud_images" "default" {
  name_regex = "^centos_6"
}

data "alicloud_instance_types" "default" {
  availability_zone = data.alicloud_zones.default.zones[0].id
}

# ECS Module
module "ecs-instance-master" {
  source  = "alibaba/ecs-instance/alicloud"
  version = "~> 2.0"

  number_of_instances = 1
  instance_type       = data.alicloud_instance_types.default.instance_types[0].id
  image_id            = data.alicloud_images.default.images[0].id
  vswitch_ids         = alicloud_vswitch.default[*].id
  security_group_ids  = [module.security_group.this_security_group_id]
}

module "ecs-instance-slave" {
  source  = "alibaba/ecs-instance/alicloud"
  version = "~> 2.0"

  number_of_instances = 1
  instance_type       = data.alicloud_instance_types.default.instance_types[0].id
  image_id            = data.alicloud_images.default.images[0].id
  vswitch_ids         = alicloud_vswitch.default[*].id
  security_group_ids  = [module.security_group.this_security_group_id]
}

# Slb Module
module "slb" {
  source = "../../"

  servers_of_master_slave_server_group = [
    {
      server_ids  = join(",", module.ecs-instance-master.this_instance_id)
      port        = "80"
      weight      = "100"
      type        = "ecs"
      server_type = "Master"
    },
    {
      server_ids  = join(",", module.ecs-instance-slave.this_instance_id)
      port        = "80"
      weight      = "90"
      server_type = "Slave"
    },
  ]
}

