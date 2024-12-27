# 使用 Ubuntu 22.04 镜像作为基础镜像
FROM ubuntu:22.04

# 使用官方的源
RUN apt-get update && apt-get install -y iputils-ping &&  apt-get install -y ca-certificates

# 设置默认命令
CMD ["ping", "jd.com"]
