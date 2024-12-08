# CTFd_auto_deploy

改编自奚玉帆的[ctfd-auto-deploy](https://github.com/pwnthebox/ctfd-auto-deploy)

因为帆哥号被封了，项目没了，后续使用不便就重新弄了一个出来



## 目前支持的插件

1：ctfd-whale  
2：ctfd-pages-theme


## 使用方法

```bash
git clone https://github.com/dr0n1/CTFd_auto_deploy
chmod 777 install.sh
./auto_deploy.sh
```

或者

```bash
bash <(curl -s https://raw.githubusercontent.com/dr0n1/CTFd_auto_deploy/main/install.sh)
```

## 实际使用

在网络畅通的情况下五分钟左右可以安装完毕

```bash
ubuntu20.04

time ./install.sh

real	3m40.916s
user	0m1.221s
sys	0m3.712s
```

## 注意事项

如果选择了安装ctfd-whale，则需要谨慎选择CTFd的版本，脚本中默认使用V3.7.3版本