# sing-box脚本

这个 Bash 脚本可以帮助你在 debian nat 系统快速部署 sing-box 代理服务器。

### 通过 curl 一键安装自定义脚本
自定义端口参数如：TR_PORT=8443 VL_PORT=9443 VL_SNI=www.microsoft.com (此为reality协议证书地址)，使用时请自行定义此参数！
```bash
TR_PORT=8443 VL_PORT=9443 VL_SNI=www.microsoft.com bash <(curl -fsSL https://raw.githubusercontent.com/hide3110/sb-debian-nat/main/install.sh)
```
### 指定版本号
可以在脚本最后添加sing-box版本号，如1.11.4
```
TR_PORT=8443 VL_PORT=9443 VL_SNI=www.microsoft.com bash <(curl -fsSL https://raw.githubusercontent.com/hide3110/sb-debian-nat/main/install.sh) 1.11.4
```

## 详细说明

- 脚本使用的自签 TLS 证书（用于 Trojan）
- 此脚本仅安装了Trojan和reality两个协议
