{
  lib,
  writeShellApplication,
  makeDesktopItem,
  symlinkJoin,
  coreutils,
  curl,
  fetchurl,
  qemu_kvm,
  runCommand,
  util-linux,
  virt-viewer,
  writeText,
  OVMF,
}:

let
  spiceGuestTools = fetchurl {
    url = "https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe";
    hash = "sha256-tb4HVIArzX9/4Mzbh3+KYiS6E6KvfYTrCHqJs7AjfaI=";
  };

  spiceWebdavd = fetchurl {
    url = "https://www.spice-space.org/download/windows/spice-webdavd/spice-webdavd-x64-2.4.msi";
    hash = "sha256-8njBf8prEp61yaRrhjSvLs+vO8qJA+uaXHh08ORfgrk=";
  };

  guestToolsReadme = writeText "README.txt" ''
    Tiny10 host integration
    =======================

    1. Run spice-guest-tools.exe as Administrator.
    2. Run spice-webdavd-x64-2.4.msi as Administrator.
    3. Restart Windows.

    Clipboard sharing will then work through the SPICE agent. The WebDAV drive
    maps to /home/rin/Documents on the host and is read-write. If the drive does
    not appear, run:

      C:\Program Files\SPICE webdavd\map-drive.bat
  '';

  guestToolsMedia = runCommand "tiny10-guest-tools" { } ''
    mkdir -p "$out"
    install -m 0644 ${spiceGuestTools} "$out/spice-guest-tools.exe"
    install -m 0644 ${spiceWebdavd} "$out/spice-webdavd-x64-2.4.msi"
    install -m 0644 ${guestToolsReadme} "$out/README.txt"
  '';

  launcher = writeShellApplication {
    name = "tiny10-vm";
    runtimeInputs = [
      coreutils
      curl
      qemu_kvm
      util-linux
      virt-viewer
    ];
    text = ''
      state_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/tiny10-vm"
      default_iso="$state_dir/tiny10-x64-23h2.iso"
      iso="$default_iso"
      install=false
      share_dir="/home/rin/Documents"

      usage() {
        printf '%s\n' \
          'Usage: tiny10-vm [--install] [--iso PATH]' \
          "" \
          "Starts the lightweight Tiny10 Windows VM. On its first run, the" \
          "launcher downloads and verifies NTDEV's Tiny10 23H2 x64 image and" \
          "creates a sparse 20 GiB system disk." \
          "" \
          "  --install   boot from the installer ISO again" \
          "  --iso PATH  use another Tiny10 ISO instead of the managed image"
      }

      while (( $# > 0 )); do
        case "$1" in
          --install)
            install=true
            shift
            ;;
          --iso)
            if (( $# < 2 )); then
              echo "tiny10-vm: --iso needs a path" >&2
              exit 2
            fi
            iso="$2"
            install=true
            shift 2
            ;;
          -h|--help)
            usage
            exit 0
            ;;
          *)
            echo "tiny10-vm: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
        esac
      done

      if [[ ! -d "$share_dir" ]]; then
        echo "tiny10-vm: shared directory not found: $share_dir" >&2
        exit 1
      fi

      mkdir -p "$state_dir"
      exec 9>"$state_dir/run.lock"
      if ! flock -n 9; then
        echo "tiny10-vm: the VM is already running" >&2
        exit 1
      fi

      if [[ "$iso" == "$default_iso" && ! -f "$iso" ]]; then
        partial="$iso.part"
        echo "Downloading the 3.6 GiB Tiny10 23H2 x64 installer..."
        curl \
          --location \
          --fail \
          --retry 3 \
          --continue-at - \
          --output "$partial" \
          "https://archive.org/download/tiny-10-23-h2/tiny10%20x64%2023h2.iso"

        echo "a11116c0645d892d6a5a7c585ecc1fa13aa66f8c7cc6b03bf1f27bd16860cc35  $partial" \
          | sha256sum --check
        mv "$partial" "$iso"
        install=true
      elif [[ ! -f "$iso" ]]; then
        echo "tiny10-vm: ISO not found: $iso" >&2
        exit 1
      fi

      disk="$state_dir/system.qcow2"
      if [[ ! -f "$disk" ]]; then
        qemu-img create -f qcow2 "$disk" 20G
        install=true
      fi

      vars="$state_dir/OVMF_VARS.fd"
      if [[ ! -f "$vars" ]]; then
        cp ${OVMF.fd}/FV/OVMF_VARS.fd "$vars"
        chmod u+w "$vars"
      fi

      boot_args=( -boot "menu=on" )
      if [[ "$install" == true ]]; then
        boot_args=( -boot "once=d,menu=on" )
      fi

      spice_socket="$state_dir/spice.sock"
      rm -f "$spice_socket"
      qemu_pid=""

      cleanup() {
        if [[ -n "$qemu_pid" ]] && kill -0 "$qemu_pid" 2>/dev/null; then
          kill "$qemu_pid"
          wait "$qemu_pid" 2>/dev/null || true
        fi
        rm -f "$spice_socket"
      }
      trap cleanup EXIT INT TERM

      qemu-system-x86_64 \
        -name Tiny10 \
        -enable-kvm \
        -machine q35,accel=kvm \
        -cpu host \
        -smp 2 \
        -m 2G \
        -drive if=pflash,format=raw,readonly=on,file=${OVMF.fd}/FV/OVMF_CODE.fd \
        -drive if=pflash,format=raw,file="$vars" \
        -drive file="$disk",format=qcow2,if=ide,discard=unmap \
        -drive file="$iso",media=cdrom,readonly=on \
        -drive file=fat:ro:${guestToolsMedia},format=raw,if=none,id=tools,readonly=on \
        -device e1000e,netdev=net0 \
        -netdev user,id=net0 \
        -device qemu-xhci,id=xhci \
        -device usb-tablet,bus=xhci.0 \
        -device usb-storage,bus=xhci.0,drive=tools,removable=on \
        -device virtio-serial-pci,id=virtio-serial0 \
        -chardev spicevmc,id=vdagent,name=vdagent \
        -device virtserialport,bus=virtio-serial0.0,chardev=vdagent,name=com.redhat.spice.0 \
        -chardev spiceport,id=webdav,name=org.spice-space.webdav.0 \
        -device virtserialport,bus=virtio-serial0.0,chardev=webdav,name=org.spice-space.webdav.0 \
        -spice "unix=on,addr=$spice_socket,disable-ticketing=on" \
        -vga qxl \
        -display none \
        -rtc base=localtime,clock=host \
        "''${boot_args[@]}" &
      qemu_pid=$!

      for _ in {1..100}; do
        [[ -S "$spice_socket" ]] && break
        if ! kill -0 "$qemu_pid" 2>/dev/null; then
          echo "tiny10-vm: QEMU exited before its display became ready" >&2
          wait "$qemu_pid"
        fi
        sleep 0.1
      done

      if [[ ! -S "$spice_socket" ]]; then
        echo "tiny10-vm: timed out waiting for the SPICE display" >&2
        exit 1
      fi

      remote-viewer \
        --title Tiny10 \
        --spice-shared-dir="$share_dir" \
        "spice+unix://$spice_socket"
    '';
  };

  desktopItem = makeDesktopItem {
    name = "tiny10-vm";
    desktopName = "Tiny10 VM";
    comment = "Lightweight Windows 10 virtual machine";
    exec = "tiny10-vm";
    icon = "computer";
    terminal = true;
    categories = [ "System" ];
  };
in
symlinkJoin {
  name = "tiny10-vm";
  paths = [
    launcher
    desktopItem
  ];
  meta = {
    description = "Lightweight KVM virtual machine launcher for Tiny10";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "tiny10-vm";
  };
}
