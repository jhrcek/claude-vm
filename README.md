# claude-vm

A simple nix flake to start a quemu based NixOS virtual machine with `claude-code` installed.

## Usage
Create an alias like
```bash
alias claude-vm="nix run github:jhrcek/claude-vm"
```

then run `claude-vm` in a directory containing project you want to work on.
The directory is mounted to `/home/dev/workspace/` in the VM.

## shutdown vm
```bash
sudo shutdown now
```
