用tc限制指定服务器的最大下载速度

无值参数
-c create限制规则
-d delte限制规则
-s show 限制规则

有值参数
--if 指定网卡
tc 为网卡设置入站队列ingress，然后设置过滤器重定向到虚拟网卡ifb0
这样网卡上的入站数据就变成了ifb0的出站数据


--ip --ip6 --dn 指定服务器的的ip或者域名，如果要限制全部流量，可以指定--ip 0.0.0.0/0 --ip6 ::/0

--rate 指定总带宽，一个整数加单位k,m,g
只设置了一个class,所以所有的filter共享rate设置的带宽


example
通过域名限制下载网速
sudo ./tc.sh -c  --if wlan0 --rate 100K  --dn taobao.com,jd.com,upos-sz-mirrorcos.bilivideo.com,upos-sz-estghw.bilivideo.com,bilibili.com,message.bilibili.com,s1.hdslb.com,data.bilibili.com,hw-v2-web-player-tracker.biliapi.net

删除创建的限制规则
sudo ./tc.sh -d --if wlan0


通过ip限制全部流量
sudo ./tc.sh -c --if wlan0 --ip 0.0.0.0/0 --ip6 ::/0 --rate 100k

