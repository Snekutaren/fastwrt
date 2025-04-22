make image PROFILE=glinet_gl-mt6000 PACKAGES="luci-app-attendedsysupgrade luci-proto-wireguard fish bash luci-app-sqm kmod-usb-storage kmod-usb-storage-uas block-mount kmod-fs-ext4 wi
reguard-tools kmod-wireguard iperf3 adguardhome luci-app-statistics luci-app-samba4 luci-app-nlbwmon htop nano luci-app-banip openssh-sftp-server luci-app-fwknopd luci-app-unbound" FILES=files/


docker dockerd luci-app-dockerman docker-compose kmod-veth kmod-ipt-nat kmod-macvlan podman




make image PROFILE=glinet_gl-mt6000 PACKAGES="luci-app-attendedsysupgrade fish bash ss luci luci-ssl luci-app-sqm fail2ban kmod-usb-storage kmod-usb-storage-uas block-mount kmod-fs-ext4 luci-proto-wireguard wireguard-tools kmod-wireguard iperf3 adguardhome luci-app-unbound luci-app-statistics luci-app-samba4 luci-app-nlbwmon htop nano luci-app-banip openssh-sftp-server openssh-server luci-app-fwknopd fwknopd" FILES=files/ V=s
tail -n