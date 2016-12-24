# SystemC - SystemD for CraftOS 1.7

### Programs

init - script which launches SystemC

systemctl - SystemC unit control interface

systemc-nspawn - SystemC container script

### Features

Ability to start/stop services (defined in <SystemC Root>/etc/systemc/system)

Ability to enable them to be run on boot

Different targets. Currently only chosen on boot

Ability to create sandboxed environment

### Other information

SystemC should work in any directory as long as it's internal structure is not changed

### TODO

More unit types

Extend boot process

Break out of bios.lua sandbox - we don't need that

Take over universe
