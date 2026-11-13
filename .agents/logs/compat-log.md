Проверить лог и файл src/compat/compat.h из upstream бранчей master, fix/compat-ubuntu.
Сравнить с локальным src/compat/compat.h, который уже исправлен от redefined и прочих ошибок сборки DKMS если они не вызваны первыми ошибками (redefined).
### Подсказка

```note
Могут помочь
ccflags-y += -Wno-redundant-decls
в Makefile
или
MAKE[0]="make -C ${kernel_source_dir} M=${dkms_tree}/${PACKAGE_NAME}/${PACKAGE_VERSION}/build KCFLAGS=-Wno-redundant-decls"
в src/dkms.conf 
(оба мы всё равно правим, хочется убрать эти ошибки без правок src/compat/compat.h)
```
Предложить мне вариант решения и дождаться обновления задач агентов.

Лог:

```log
 cat /var/lib/dkms/amneziawg/3.1.20260812/build/make.log
DKMS (dkms-3.4.4) make.log for amneziawg/3.1.20260812 for kernel 6.12.0-273.el10.x86_64 (x86_64)
Fri Nov 13 07:26:28 AM MSK 2026

Building module(s)
# command: make -j2 KERNELRELEASE=6.12.0-273.el10.x86_64 -C /lib/modules/6.12.0-273.el10.x86_64/build M=/var/lib/dkms/amneziawg/3.1.20260812/build
make: Entering directory '/usr/src/kernels/6.12.0-273.el10.x86_64'
  CC [M]  /var/lib/dkms/amneziawg/3.1.20260812/build/main.o
  CC [M]  /var/lib/dkms/amneziawg/3.1.20260812/build/noise.o
In file included from <command-line>:
/var/lib/dkms/amneziawg/3.1.20260812/build/compat/compat.h:1300:9: warning: "timer_container_of" redefined
 1300 | #define timer_container_of from_timer
      |         ^~~~~~~~~~~~~~~~~~
In file included from <command-line>:
/var/lib/dkms/amneziawg/3.1.20260812/build/compat/compat.h:1300:9: warning: "timer_container_of" redefined
 1300 | #define timer_container_of from_timer
      |         ^~~~~~~~~~~~~~~~~~
In file included from ./include/linux/workqueue.h:10,
                 from ./include/linux/srcu.h:21,
                 from ./include/linux/notifier.h:16,
                 from ./arch/x86/include/asm/uprobes.h:13,
                 from ./include/linux/uprobes.h:61,
                 from ./include/linux/mm_types.h:16,
                 from ./include/linux/mmzone.h:22,
                 from ./include/linux/gfp.h:7,
                 from ./include/linux/xarray.h:16,
                 from ./include/linux/list_lru.h:14,
                 from ./include/linux/fs.h:14,
                 from ./include/linux/highmem.h:5,
                 from ./include/linux/bvec.h:10,
                 from ./include/linux/skbuff.h:17,
                 from ./include/linux/ip.h:16,
                 from ./include/linux/if_tunnel.h:5,
                 from ./include/net/ip_tunnels.h:5,
                 from ./include/net/udp_tunnel.h:5,
                 from /var/lib/dkms/amneziawg/3.1.20260812/build/compat/udp_tunnel/udp_tunnel_partial_compat.h:154,
                 from /var/lib/dkms/amneziawg/3.1.20260812/build/compat/compat.h:70:
./include/linux/timer.h:132:9: note: this is the location of the previous definition
  132 | #define timer_container_of(var, callback_timer, timer_fieldname)        \
      |         ^~~~~~~~~~~~~~~~~~
In file included from ./include/linux/workqueue.h:10,
                 from ./include/linux/srcu.h:21,
                 from ./include/linux/notifier.h:16,
                 from ./arch/x86/include/asm/uprobes.h:13,
                 from ./include/linux/uprobes.h:61,
                 from ./include/linux/mm_types.h:16,
                 from ./include/linux/mmzone.h:22,
                 from ./include/linux/gfp.h:7,
                 from ./include/linux/xarray.h:16,
                 from ./include/linux/list_lru.h:14,
                 from ./include/linux/fs.h:14,
                 from ./include/linux/highmem.h:5,
                 from ./include/linux/bvec.h:10,
                 from ./include/linux/skbuff.h:17,
                 from ./include/linux/ip.h:16,
                 from ./include/linux/if_tunnel.h:5,
                 from ./include/net/ip_tunnels.h:5,
                 from ./include/net/udp_tunnel.h:5,
                 from /var/lib/dkms/amneziawg/3.1.20260812/build/compat/udp_tunnel/udp_tunnel_partial_compat.h:154,
                 from /var/lib/dkms/amneziawg/3.1.20260812/build/compat/compat.h:70:
./include/linux/timer.h:132:9: note: this is the location of the previous definition
  132 | #define timer_container_of(var, callback_timer, timer_fieldname)        \
      |         ^~~~~~~~~~~~~~~~~~
/var/lib/dkms/amneziawg/3.1.20260812/build/compat/compat.h:1305:8: error: redefinition of ‘struct sockaddr_inet’
 1305 | struct sockaddr_inet {
      |        ^~~~~~~~~~~~~
/var/lib/dkms/amneziawg/3.1.20260812/build/compat/compat.h:1305:8: error: redefinition of ‘struct sockaddr_inet’
 1305 | struct sockaddr_inet {
      |        ^~~~~~~~~~~~~
In file included from ./include/net/flow_dissector.h:6,
                 from ./include/linux/skbuff.h:30:
./include/linux/in6.h:22:8: note: originally defined here
   22 | struct sockaddr_inet {
      |        ^~~~~~~~~~~~~
In file included from ./include/net/flow_dissector.h:6,
                 from ./include/linux/skbuff.h:30:
./include/linux/in6.h:22:8: note: originally defined here
   22 | struct sockaddr_inet {
      |        ^~~~~~~~~~~~~
/var/lib/dkms/amneziawg/3.1.20260812/build/compat/compat.h:1314:20: error: static declaration of ‘netif_threaded_enable’ follows non-static declaration
 1314 | static inline void netif_threaded_enable(struct net_device *dev) { }
      |                    ^~~~~~~~~~~~~~~~~~~~~
/var/lib/dkms/amneziawg/3.1.20260812/build/compat/compat.h:1314:20: error: static declaration of ‘netif_threaded_enable’ follows non-static declaration
 1314 | static inline void netif_threaded_enable(struct net_device *dev) { }
      |                    ^~~~~~~~~~~~~~~~~~~~~
In file included from ./include/net/ip_tunnels.h:6:
./include/linux/netdevice.h:595:6: note: previous declaration of ‘netif_threaded_enable’ with type ‘void(struct net_device *)’
  595 | void netif_threaded_enable(struct net_device *dev);
      |      ^~~~~~~~~~~~~~~~~~~~~
In file included from ./include/net/ip_tunnels.h:6:
./include/linux/netdevice.h:595:6: note: previous declaration of ‘netif_threaded_enable’ with type ‘void(struct net_device *)’
  595 | void netif_threaded_enable(struct net_device *dev);
      |      ^~~~~~~~~~~~~~~~~~~~~
/var/lib/dkms/amneziawg/3.1.20260812/build/compat/compat.h:1328:8: error: redefinition of ‘struct rtnl_newlink_params’
 1328 | struct rtnl_newlink_params {
      |        ^~~~~~~~~~~~~~~~~~~
/var/lib/dkms/amneziawg/3.1.20260812/build/compat/compat.h:1328:8: error: redefinition of ‘struct rtnl_newlink_params’
 1328 | struct rtnl_newlink_params {
      |        ^~~~~~~~~~~~~~~~~~~
In file included from ./include/net/neighbour.h:31,
                 from ./include/net/dst.h:20,
                 from ./include/net/sock.h:66,
                 from ./include/linux/tcp.h:19,
                 from ./include/linux/ipv6.h:102,
                 from ./include/net/dsfield.h:12,
                 from ./include/net/ip_tunnels.h:13:
./include/net/rtnetlink.h:81:8: note: originally defined here
   81 | struct rtnl_newlink_params {
      |        ^~~~~~~~~~~~~~~~~~~
In file included from ./include/net/neighbour.h:31,
                 from ./include/net/dst.h:20,
                 from ./include/net/sock.h:66,
                 from ./include/linux/tcp.h:19,
                 from ./include/linux/ipv6.h:102,
                 from ./include/net/dsfield.h:12,
                 from ./include/net/ip_tunnels.h:13:
./include/net/rtnetlink.h:81:8: note: originally defined here
   81 | struct rtnl_newlink_params {
      |        ^~~~~~~~~~~~~~~~~~~
/var/lib/dkms/amneziawg/3.1.20260812/build/compat/compat.h:1335:27: error: conflicting types for ‘rtnl_newlink_link_net’; have ‘struct net *(struct rtnl_newlink_params *)’
 1335 | static inline struct net *rtnl_newlink_link_net(struct rtnl_newlink_params *p)
      |                           ^~~~~~~~~~~~~~~~~~~~~
./include/net/rtnetlink.h:93:27: note: previous definition of ‘rtnl_newlink_link_net’ with type ‘struct net *(struct rtnl_newlink_params *)’
   93 | static inline struct net *rtnl_newlink_link_net(struct rtnl_newlink_params *p)
      |                           ^~~~~~~~~~~~~~~~~~~~~
/var/lib/dkms/amneziawg/3.1.20260812/build/compat/compat.h:1335:27: error: conflicting types for ‘rtnl_newlink_link_net’; have ‘struct net *(struct rtnl_newlink_params *)’
 1335 | static inline struct net *rtnl_newlink_link_net(struct rtnl_newlink_params *p)
      |                           ^~~~~~~~~~~~~~~~~~~~~
./include/net/rtnetlink.h:93:27: note: previous definition of ‘rtnl_newlink_link_net’ with type ‘struct net *(struct rtnl_newlink_params *)’
   93 | static inline struct net *rtnl_newlink_link_net(struct rtnl_newlink_params *p)
      |                           ^~~~~~~~~~~~~~~~~~~~~
make[2]: *** [scripts/Makefile.build:229: /var/lib/dkms/amneziawg/3.1.20260812/build/main.o] Error 1
make[2]: *** Waiting for unfinished jobs....
make[2]: *** [scripts/Makefile.build:229: /var/lib/dkms/amneziawg/3.1.20260812/build/noise.o] Error 1
make[1]: *** [/usr/src/kernels/6.12.0-273.el10.x86_64/Makefile:2003: /var/lib/dkms/amneziawg/3.1.20260812/build] Error 2
make: *** [Makefile:242: __sub-make] Error 2
make: Leaving directory '/usr/src/kernels/6.12.0-273.el10.x86_64'

# exit code: 2
```
