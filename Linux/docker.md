# Docker
## Install

https://docs.docker.com/install/linux/docker-ce/fedora/

```
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install docker-ce docker-ce-cli containerd.ioo
sudo systemctl start docker
sudo docker run hello-world
```

Fedora 31:
  * Error
```
[benoit@benoit-dalibo ~]$ sudo docker run hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
1b930d010525: Pull complete 
Digest: sha256:4fe721ccc2e8dc7362278a29dc660d833570ec2682f4e4194f4ee23e415e1064
Status: Downloaded newer image for hello-world:latest
docker: Error response from daemon: OCI runtime create failed: container_linux.go:346: starting container process caused "process_linux.go:297: applying cgroup configuration for process caused \"open /sys/fs/cgroup/docker/cpuset.cpus.effective: no such file or directory\"": unknown.
ERRO[0002] error waiting for container: context canceled 
```
  * Details: https://github.com/docker/for-linux/issues/665#issuecomment-548845458
  * Manip
    * Install grubby
```
dnf info --installed grubby
sudo dnf install -y grubby
```
    * List all kernel startup parameter info
```
sudo grubby --info=ALL
```
    * deactivate cgroup V2 (2 choices):
```
sudo grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=0"
sudo grubby --update-kernel=/boot/vmlinuz-5.3.15-300.fc31.x86_64 --args="systemd.unified_cgroup_hierarchy=0"
```

Access to docker socket:
  * Error 
```
docker: Got permission denied while trying to connect to the Docker daemon socket at ...
```
  * Manip
```
sudo useradd -a -G docker $USER
```

## Commands 

list :
```
man docker-image-ls
ddocker image list
ddocker image list --no-trunc
docker image list --filter dangling=true
```


