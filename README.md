# proxy-nio

NIO proxy

## Feature | Plan

- [x] socks5 proxy with auth
- [x] shadowsocks protocol(udp is in plan)
- [x] socsk5 udp relay
- [ ] socks5 forward
- [ ] http(s) proxy
- [ ] sniffer http(s) traffic
- [ ] support iOS platform

## Requirement

* macOS 10.15
* swift 5.3

## Check UDP

```shell
python udpchk.py -p localhost  -P 1080
```

## RFC Documents

1. [SOCKS Protocol Version 5](https://tools.ietf.org/html/rfc1928)
2. [Username/Password Authentication for SOCKS V5](https://tools.ietf.org/html/rfc1929)

