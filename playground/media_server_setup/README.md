# Media Server Setup

I have an old ThinkPad-X201 that is a very good computer, the idea is to use it as a media server. That is just using the kodi package.

I can access kodi from LightDM so I think no DE or WM is necessary to have it. But I like to know I can use the computer for other things than just watch something.

The idea is to use this computer directly connected to the TV (I will use a DP-HDMI wire to do it), not to access some port on localhost from the TV, in general TV's OS web browsers are garbage and will not run the videos correctly.

I disabled the password login from the ssh server of the machine.

The server is running Linux Mint 21.

## Run setup

```terminal
ansible-playbook -i inv/media_server.ini plays/media_server_setup.yml --ask-become-pass
```

## After setup

1. Configure kodi with the location to look up for movies (or others).
1. (opt) Configure kodi to be available on a particular port in localhost. (If you want to control it with your cellphone or something)
1. (opt) Configure the ThinkPad-X201 to do nothing when closing: Settings -> Power Management

## Hardware specifications:

### CPU

```terminal
pab@pab-ThinkPad-X201:~$ lscpu
Architecture:            x86_64
  CPU op-mode(s):        32-bit, 64-bit
  Address sizes:         36 bits physical, 48 bits virtual
  Byte Order:            Little Endian
CPU(s):                  4
  On-line CPU(s) list:   0-3
Vendor ID:               GenuineIntel
  Model name:            Intel(R) Core(TM) i5 CPU       M 520  @ 2.40GHz
    CPU family:          6
    Model:               37
    Thread(s) per core:  2
    Core(s) per socket:  2
    Socket(s):           1
    Stepping:            5
    Frequency boost:     enabled
    CPU max MHz:         2400,0000
    CPU min MHz:         1199,0000
    BogoMIPS:            4788.45
    Flags:               fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ht tm pbe syscall nx rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl
                         xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid sse4_1 sse4_2 popcnt aes lahf_lm pti ssbd ibrs ibpb stibp tpr_shadow v
                         nmi flexpriority ept vpid dtherm ida arat flush_l1d
Virtualization features:
  Virtualization:        VT-x
Caches (sum of all):
  L1d:                   64 KiB (2 instances)
  L1i:                   64 KiB (2 instances)
  L2:                    512 KiB (2 instances)
  L3:                    3 MiB (1 instance)
NUMA:
  NUMA node(s):          1
  NUMA node0 CPU(s):     0-3
Vulnerabilities:
  Itlb multihit:         KVM: Mitigation: VMX disabled
  L1tf:                  Mitigation; PTE Inversion; VMX conditional cache flushes, SMT vulnerable
  Mds:                   Vulnerable: Clear CPU buffers attempted, no microcode; SMT vulnerable
  Meltdown:              Mitigation; PTI
  Mmio stale data:       Unknown: No mitigations
  Retbleed:              Not affected
  Spec store bypass:     Mitigation; Speculative Store Bypass disabled via prctl and seccomp
  Spectre v1:            Mitigation; usercopy/swapgs barriers and __user pointer sanitization
  Spectre v2:            Mitigation; Retpolines, IBPB conditional, IBRS_FW, STIBP conditional, RSB filling, PBRSB-eIBRS Not affected
  Srbds:                 Not affected
  Tsx async abort:       Not affected
```

### Memory

```
pab@pab-ThinkPad-X201:~$ free -h
               total        used        free      shared  buff/cache   available
Mem:           7,6Gi       1,2Gi       5,1Gi       232Mi       1,3Gi       5,9Gi
Swap:          2,0Gi          0B       2,0Gi
```

### Storage

1 1TB WD Element 3.0 USB External Hard Drive.

1 1TB HDD using a SATA 3 to USB adaptor.
