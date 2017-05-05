# OpenIndiana's openQA tests
#
# Copyright © 2017 Michal Nowak
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run Firefly failsafe image in illumos KVM (nested)
#   https://github.com/joyent/illumos-kvm-cmd
#   https://omnios.omniti.com/wiki.php/VirtualMachinesKVM
#   https://sourceforge.net/projects/fireflyfailsafe/
# Maintainer: Michal Nowak <mnowak@startmail.com>

use base 'consoletest';
use strict;
use testapi;
use utils 'deploy_kvm';

sub run() {
    select_console 'user-console';

    my $image = 'firefly_05052016.iso';
    deploy_kvm($image);

    my $macaddr = '90:b8:d0:c0:ff:ee';
    script_sudo(
        "qemu-kvm -enable-kvm -vga std -drive file=$image,media=cdrom,if=ide "
          . "-vnc 0.0.0.0:0 -no-hpet -net nic,vlan=0,name=net0,model=virtio,macaddr=$macaddr "
          . "-net vnic,vlan=0,name=net0,ifname=vnic0,macaddr=$macaddr "
          . "-boot d -m 512 -serial /dev/$testapi::serialdev 2>&1 | tee qemu_kvm.log",
        0
    );
    sleep 3;
    select_console 'vnc';

    assert_screen('firefly-bootloader');
    send_key 'esc';
    assert_screen('firefly-okprompt');
    type_string "boot\n";
    assert_screen('firefly-uname');
    assert_screen('firefly-prompt');

    select_console 'root-console';
    my $kvmstat_output = script_output('kvmstat 1 5 | grep -v "pid vcpu"');
    die "'kvmstat' did not produce statistics" unless $kvmstat_output;

    select_console 'vnc';

    assert_script_run 'uname -a';
    type_string "poweroff\n";
    record_soft_failure 'illumos will not poweroff under QEMU';
    select_console 'user-console';
    send_key 'ctrl-c';
    sleep 3;
    upload_logs('qemu_kvm.log');

    assert_script_sudo('modunload -i $(modinfo | grep kvm | awk "{ print $1 }")');
    assert_script_sudo('modinfo | grep kvm && false || true');
    reset_console('vnc');    # To make sure we activate VNC of new VM on reconnect
}

1;

# vim: set sw=4 et:
