terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

variable "do_token" {
  type      = string
  sensitive = true
}

variable "pvt_key" {
  type      = string
  sensitive = true
}

provider "digitalocean" {
  token = var.do_token
}

# resource "digitalocean_project" "playground" {
#   name        = "playground"
#   description = "My playground"
#   purpose     = "Practice"
#   environment = "Development"
#   resources = [
#     digitalocean_droplet.web.urn,
#     digitalocean_droplet.web2.urn,
#     # digitalocean_ssh_key.t480.name,
#     # digitalocean_vpc.snetwork.name,
#     digitalocean_loadbalancer.security-lb.urn,
#     digitalocean_firewall.web.urn,
#     digitalocean_droplet.bastion.urn,
#     digitalocean_firewall.bastion.urn,
#   ]
# }

data "digitalocean_ssh_key" "t480" {
  name = "t480"
  # public_key = file("~/.ssh/id_rsa.pub")
}

resource "digitalocean_vpc" "snetwork" {
  name     = "security-network"
  region   = "ams3"
  ip_range = "192.168.10.0/24"
}

output "web" {
  value = digitalocean_droplet.web
}

output "bastion" {
  value = digitalocean_droplet.bastion
}

output "snetwork" {
  value = digitalocean_vpc.snetwork
}

output "ssh_key_data" {
  value = data.digitalocean_ssh_key.t480
}

resource "digitalocean_loadbalancer" "security-lb" {
  name     = "security-lb"
  region   = "ams3"
  vpc_uuid = digitalocean_vpc.snetwork.id

  sticky_sessions {
    type               = "cookies"
    cookie_name        = "lb"
    cookie_ttl_seconds = 120
  }

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"

    target_port     = 8080
    target_protocol = "http"
  }

  healthcheck {
    port     = 8080
    protocol = "http"
    path     = "/"
  }

  droplet_ids = digitalocean_droplet.web.*.id
}

resource "digitalocean_firewall" "web" {
  name = "web-only-lb-and-ssh"

  droplet_ids = digitalocean_droplet.web.*.id

  inbound_rule {
    protocol           = "tcp"
    port_range         = "22"
    source_droplet_ids = [digitalocean_droplet.bastion.id]
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "80"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "53"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "53"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "443"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

resource "digitalocean_droplet" "bastion" {
  image    = "ubuntu-20-04-x64"
  name     = "security-bastion"
  region   = "ams3"
  size     = "s-1vcpu-1gb"
  vpc_uuid = digitalocean_vpc.snetwork.id

  ssh_keys = [data.digitalocean_ssh_key.t480.id]
}

resource "digitalocean_firewall" "bastion" {
  name = "only-lb-and-ssh"

  droplet_ids = digitalocean_droplet.web.*.id

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol   = "tcp"
    port_range = "1-65535"
  }

  outbound_rule {
    protocol   = "udp"
    port_range = "1-65535"
  }

  outbound_rule {
    protocol   = "icmp"
    port_range = "1-65535"
  }
}

resource "digitalocean_droplet" "web" {
  count              = 2
  image              = "ubuntu-18-04-x64"
  name               = "web${count.index + 1}"
  region             = "ams3"
  size               = "s-1vcpu-1gb"
  private_networking = true
  vpc_uuid           = digitalocean_vpc.snetwork.id

  // Добавление приватного ключа на создаваемый сервер
  // Обращение к datasource выполняется через data.
  ssh_keys = [data.digitalocean_ssh_key.t480.id]
  connection {
    host        = self.ipv4_address
    user        = "root"
    type        = "ssh"
    private_key = file(var.pvt_key)
    timeout     = "2m"
  }
}

# resource "digitalocean_droplet" "web2" {
#   image              = "ubuntu-18-04-x64"
#   name               = "web2"
#   region             = "ams3"
#   size               = "s-1vcpu-1gb"
#   private_networking = true
#   vpc_uuid           = digitalocean_vpc.snetwork.id

#   // Добавление приватного ключа на создаваемый сервер
#   // Обращение к datasource выполняется через data.
#   # ssh_keys = [
#   #   "${digitalocean_ssh_key.t480.id}"
#   # ]
#   connection {
#     host        = self.ipv4_address
#     user        = "root"
#     type        = "ssh"
#     private_key = file(var.pvt_key)
#     timeout     = "2m"
#   }
# }
