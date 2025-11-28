nano setup-wg-warp.sh && chmod +x setup-wg-warp.sh

sudo ./setup-wg-warp.sh

ip netns exec warpns warp-cli register

ip netns exec warpns warp-cli set mode tun
ip netns exec warpns warp-cli connect


wg-quick down wg0
wg-quick up wg0