#!/bin/sh
set -e
: "${FRP_TOKEN:?Biến FRP_TOKEN bắt buộc phải được đặt trên Railway}"
sed "s/__FRP_TOKEN__/${FRP_TOKEN}/" /etc/frp/frps.toml.template > /etc/frp/frps.toml
exec frps -c /etc/frp/frps.toml
