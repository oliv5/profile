#!/bin/sh
#~ https://oneuptime.com/blog/post/2026-03-20-ipv6-slow-performance/view
#~ https://oneuptime.com/blog/post/2026-03-20-ipv6-mtu-path-mtu-discovery/view
#~ https://oneuptime.com/blog/post/2026-03-20-configure-dnsmasq-ipv6-dns-server/view
#~ https://oneuptime.com/blog/post/2026-03-20-radvd-router-advertisements-linux/view
#~ https://oneuptime.com/blog/post/2026-03-20-configure-unbound-listen-ipv6/view
#~ https://oneuptime.com/blog/post/2026-03-20-configure-unbound-recursive-ipv6-dns/view
#~ https://oneuptime.com/blog/post/2026-03-20-proxmox-ipv6/view
#~ https://oneuptime.com/blog/post/2026-03-20-configure-dhcp-options-gateway-dns-domain/view
#~ https://oneuptime.com/blog/post/2026-03-20-assign-static-ipv4-ip-command-linux/view
#~ https://oneuptime.com/blog/post/2026-03-20-slaac-address-deprecation/view
#~ https://oneuptime.com/blog/post/2026-02-08-how-to-use-docker-compose-devices-configuration/view
#~ https://oneuptime.com/blog/post/2026-01-16-docker-mysql-mariadb/view
#~ https://oneuptime.com/blog/post/2026-03-20-nfs-restrict-access-exports-ipv4/view
#~ https://oneuptime.com/blog/post/2026-01-16-docker-multiple-compose-files/view
#~ https://oneuptime.com/blog/post/2026-03-02-check-apparmor-status-loaded-profiles-ubuntu/view
#~ https://oneuptime.com/blog/post/2026-02-08-how-to-view-contents-of-a-docker-volume/view
#~ https://oneuptime.com/blog/post/2026-03-02-how-to-troubleshoot-network-interface-not-coming-up-on-ubuntu/view

############################
# Temporary enable/disable ipv4/ipv6 until next reboot
alias ipv4_disable='for V in $(sysctl -a -N -r "net.ipv4.conf.*.disable_ipv4"); do sudo sysctl -w $V=1; done'
alias ipv4_enable='for V in $(sysctl -a -N -r "net.ipv4.conf.*.disable_ipv4"); do sudo sysctl -w $V=0; done'
alias ipv6_disable='for V in $(sysctl -a -N -r "net.ipv6.conf.*.disable_ipv6"); do sudo sysctl -w $V=1; done'
alias ipv6_enable='for V in $(sysctl -a -N -r "net.ipv6.conf.*.disable_ipv6"); do sudo sysctl -w $V=0; done'
# Persistent enable/disable ipv4/ipv6 in sysctl.conf
alias ipv4_disable_persistent='sudo sed -i -e "s/disable_ipv4\s*=.*/disable_ipv4 = 1/" /etc/sysctl.conf'
alias ipv4_enable_persistent='sudo sed -i -e "s/disable_ipv4\s*=.*/disable_ipv4 = 0/" /etc/sysctl.conf'
alias ipv6_disable_persistent='sudo sed -i -e "s/disable_ipv6\s*=.*/disable_ipv6 = 1/" /etc/sysctl.conf'
alias ipv6_enable_persistent='sudo sed -i -e "s/disable_ipv6\s*=.*/disable_ipv6 = 0/" /etc/sysctl.conf'

############################
# IPv6
ipv6_supported() {
  test -f /proc/net/if_inet6 && echo "IPv6 supported" || echo "IPv6 not supported"
}
ipv6_enabled() {
  sysctl -a 2>/dev/null | grep disable_ipv6
}

############################
# Local IP addr get
ip_addr_get() {
  local FILTER="${1:-inet}"
  if [ $# -gt 1 ]; then
    shift
    for DEV; do
      ip address show dev "$DEV"
    done
  else
    ip address
  fi | awk "/$FILTER/ {print \$2}"
}

ipv4_addr_get() {
  ip_addr_get "inet " "$@"
}

ipv6_addr_get() {
  ip_addr_get "inet6" "$@"
}

############################
# iptables list all
iptables_ls() {
  for TABLE in filter nat mangle raw security; do
    echo "** Table $TABLE **"
    sudo iptables -vL -t $TABLE
  done
}

# iptables flush all (must be done by a script at once)
iptables_flush() {
  # Set table filter policies to ACCEPT
  sudo iptables -t filter -P INPUT ACCEPT
  sudo iptables -t filter -P FORWARD ACCEPT
  sudo iptables -t filter -P OUTPUT ACCEPT
  # Remove all existing rules
  for TABLE in filter nat mangle raw security; do
    sudo iptables -t $TABLE -F	# All rules
    sudo iptables -t $TABLE -X	# Delete all user defined-chains (ex: ssh established session)
  done
}

############################
# ip6tables list all
ip6tables_ls() {
  for TABLE in filter nat mangle raw security; do
    echo "** Table $TABLE **"
    sudo ip6tables -vL -t $TABLE
  done
}

# iptables flush all (must be done by a script at once)
ip6tables_flush() {
  # Set table filter policies to ACCEPT
  sudo ip6tables -t filter -P INPUT ACCEPT
  sudo ip6tables -t filter -P FORWARD ACCEPT
  sudo ip6tables -t filter -P OUTPUT ACCEPT
  # Remove all existing rules
  for TABLE in filter nat mangle raw security; do
    sudo ip6tables -t $TABLE -F	# All rules
    sudo ip6tables -t $TABLE -X	# Delete all user defined-chains (ex: ssh established session)
  done
}

############################
# Check IPv6 performences compared to IPv4
# https://oneuptime.com/blog/post/2026-03-20-ipv6-slow-performance/view
ip_compare_speed() {
  echo "IPv4 speed:"
  time curl -4 -s -o /dev/null 'https://speed.cloudflare.com/__down?bytes=50000000'
  echo ""
  echo "IPv6 speed:"
  time curl -6 -s -o /dev/null 'https://speed.cloudflare.com/__down?bytes=50000000'
}

ip_compare_latency() {
  # Compare ping latency
  echo "IPv4 latency to Google:"
  ping -c 10 8.8.8.8 | tail -3
  echo ""
  echo "IPv6 latency to Google:"
  ping -6 -c 10 2001:4860:4860::8888 | tail -3

  # Use mtr for path-level comparison
  echo "IPv4 path:"
  mtr -n -r -4 8.8.8.8
  echo ""
  echo "IPv6 path:"
  mtr -n -r -6 2001:4860:4860::8888
}

ipv6_test_mtu() {
  # Test with progressively larger ICMPv6 payloads
  echo "Packet size test over IPv6:"
  for size in 1000 1232 1400 1452; do
      result=$(ping -6 -M do -c 3 -s "$size" 2001:4860:4860::8888 2>&1)
      if echo "$result" | grep -q "3 received"; then
          echo "  payload $size bytes: OK"
      else
          echo "  payload $size bytes: FAIL/PARTIAL"
      fi
  done
  # 1232-byte payload ~= 1280-byte IPv6 packet, 1452-byte payload ~= 1500-byte IPv6 packet
  # If larger payloads fail or stall: likely PMTUD / MTU black hole
  # Fix on the local host firewall: allow ICMPv6 Packet Too Big
  #~ sudo ip6tables -A INPUT -p icmpv6 --icmpv6-type 2 -j ACCEPT
}

ipv6_check_tcp_perf() {
  # Key metrics:
  # cwnd: congestion window (larger = better throughput)
  # rtt: round-trip time
  # retrans: retransmissions (if high, indicates packet loss)
  # rcvbuf/sndbuf: socket buffers

  # Check TCP congestion window with ss (run while an IPv6 TCP transfer is active)
  ss -tin6 state established | grep cwnd

  # View detailed TCP metrics for an IPv6 connection
  ss -tin6 state established | head -20

  # Check TCP buffer sizes
  sysctl net.core.rmem_max net.core.wmem_max
  sysctl net.ipv4.tcp_rmem net.ipv4.tcp_wmem  # Applies to IPv6 too
}

ipv6_analyse_routing() {
  # IPv6 traffic may take a less direct path than IPv4, adding latency
  # Compare per-hop latency and look for an unexpectedly longer IPv6 path

  # Is IPv6 taking a longer path than IPv4?
  echo "IPv4 path to Google:"
  traceroute -n 8.8.8.8 | tail -n +2 | wc -l
  echo "IPv6 path to Google:"
  traceroute -n -6 2001:4860:4860::8888 | tail -n +2 | wc -l

  # Compare paths in detail
  traceroute -n 8.8.8.8
  traceroute -n -6 2001:4860:4860::8888
}

ipv6_check_tcp_segmentation_offload() {
  # On some systems, NIC offload features can interact badly with certain drivers or paths
  ethtool -k eth0 | grep "tcp-segmentation-offload\|generic-segmentation\|large-receive"

  # Try disabling TSO/GSO temporarily to test if it improves IPv6 performance
  # (only for testing - measure before and after)
  sudo ethtool -K eth0 tso off
  sudo ethtool -K eth0 gso off
  #~ iperf3 -c server.example.com -6 -t 10
  ip_compare_speed
  sudo ethtool -K eth0 tso on
  sudo ethtool -K eth0 gso on
}

ipv6_ckeck_happy_eyeballs_delay_impact() {
  # If applications are slow to start over IPv6:
  # Check if Happy Eyeballs fallback delay is too long
  # RFC 8305 recommends a 250ms connection-attempt delay, but application defaults vary
  # 1. DNS response time for AAAA vs A
  # 2. SYN timeout before fallback to IPv4

  # Test dual-stack behavior with curl and measure connection time
  curl -w "Remote IP: %{remote_ip}\nConnect: %{time_connect}s\nTTFB: %{time_starttransfer}s\n" \
      -s -o /dev/null https://example.com

  # Compare forced IPv6 and IPv4 timings separately
  curl -6 -w "IPv6 Connect: %{time_connect}s\nIPv6 TTFB: %{time_starttransfer}s\n" \
      -s -o /dev/null https://example.com

  curl -4 -w "IPv4 Connect: %{time_connect}s\nIPv4 TTFB: %{time_starttransfer}s\n" \
      -s -o /dev/null https://example.com
}
