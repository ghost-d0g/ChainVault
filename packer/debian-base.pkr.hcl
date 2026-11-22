packer {
    required_plugins{
        qemu = {
            version = ">=1.1.0"
            source = "github.com/hashicorp/qemu"
        }
    }
}

variable "iso_version" {
    type = string
    default = "13.7.0"
}

variable "iso_checksum" {
    type =string 
    #default = "file:https://cdimage.debian.org/cdimage/archive/13.7.0/amd64/iso-cd/SHA256SUMS"
    default="sha256:a7ef94ac2fb9a7fec454552abd629b7cc9d5155c886165a45649f5ce6167e355"
}

variable "output_directory" {
    type = string
    default = "output-debian-base"
}

variable "cpus" {
    type = number
    default = 2
}

variable "memory" {
    type = number 
    default = 2048 
}

variable "disk_size" {
    type = string 
    default = "20G"
}

variable "accelerator" {
    type = string 
    default = "kvm"
}

variable "ssh_username" {
    type = string 
    default = "packer"
}

variable "ssh_password" {
    type = string 
    default = "packer"
}

source "qemu" "debian_base" {
    iso_urls = [
        "https://cdimage.debian.org/debian-cd/${var.iso_version}/amd64/iso-cd/debian-${var.iso_version}-amd64-netinst.iso",
        "https://cdimage.debian.org/cdimage/archive/${var.iso_version}/amd64/iso-cd/debian-${var.iso_version}-amd64-netinst.iso",
    ]
    iso_checksum = var.iso_checksum

    accelerator = var.accelerator
    cpus = var.cpus
    memory = var.memory
    disk_size = var.disk_size
    disk_interface = "virtio"
    net_device = "virtio-net"
    format = "qcow2"
    headless = false

    output_directory = var.output_directory
    vm_name = "debian13-base.qcow2"

    http_directory = "http"
    boot_wait = "5s"
    boot_command = [
      "<wait><wait><wait><esc><wait><wait><wait>",
      "/install.amd/vmlinuz initrd=/install.amd/initrd.gz ",
      "auto=true priority=critical ",
      "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
      "hostname=debian-base domain=lab.local ",
      "<enter>",
    ]
    

    communicator = "ssh"
    ssh_username = var.ssh_username
    ssh_password = var.ssh_password
    ssh_timeout = "40m"
    shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"

}

build{
    sources = ["source.qemu.debian_base"]

    provisioner "shell" {
        execute_command = "echo '${var.ssh_password}' | sudo -S -E bash '{{ .Path}}'"
        inline = [
            "cat /etc/os-release",
            "dpkg-query -W >/tmp/packages.txt",
            "wc -l /tmp/packages.txt",
        ]
    
    }
    provisioner "file" {
        source = "/tmp/packages.txt"
        destination = "${var.output_directory}/packages.txt"
        direction = "download"
    }
    }
