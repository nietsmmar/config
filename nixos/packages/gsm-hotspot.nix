{ writeShellApplication, networkmanager, gnugrep }:

writeShellApplication {
  name = "gsm-hotspot";
  runtimeInputs = [ networkmanager gnugrep ];

  text = ''
    profile="Laptop Hotspot"

    find_wifi() {
      nmcli -t -f DEVICE,TYPE device status \
        | while IFS=: read -r device type; do
            if [ "$type" = wifi ]; then
              printf '%s\n' "$device"
              break
            fi
          done
    }

    exists() {
      nmcli -g NAME connection show | grep -Fxq "$profile"
    }

    active() {
      nmcli -g NAME connection show --active | grep -Fxq "$profile"
    }

    create_profile() {
      wifi=$(find_wifi)
      if [ -z "$wifi" ]; then
        echo "No Wi-Fi adapter was found." >&2
        exit 1
      fi

      printf 'Hotspot name [LaptopHotspot]: '
      read -r ssid
      ssid=''${ssid:-LaptopHotspot}

      printf 'Password (8-63 characters): '
      read -r -s password
      printf '\n'
      if [ "''${#password}" -lt 8 ] || [ "''${#password}" -gt 63 ]; then
        echo "The password must contain 8-63 characters." >&2
        exit 1
      fi

      nmcli connection add \
        type wifi \
        ifname "$wifi" \
        con-name "$profile" \
        ssid "$ssid" \
        802-11-wireless.mode ap \
        802-11-wireless.band bg \
        wifi-sec.key-mgmt wpa-psk \
        wifi-sec.psk "$password" \
        ipv4.method shared \
        ipv6.method disabled \
        connection.autoconnect no
    }

    case "''${1:-toggle}" in
      setup)
        if exists; then
          echo "The '$profile' profile already exists."
        else
          create_profile
          echo "Hotspot profile created. It is now available in nm-applet."
        fi
        ;;
      on)
        exists || create_profile
        nmcli connection up "$profile"
        ;;
      off)
        if active; then
          nmcli connection down "$profile"
        else
          echo "Hotspot is already off."
        fi
        ;;
      toggle)
        if active; then
          nmcli connection down "$profile"
        else
          exists || create_profile
          nmcli connection up "$profile"
        fi
        ;;
      status)
        if active; then
          echo "Hotspot is on."
        elif exists; then
          echo "Hotspot is off."
        else
          echo "Hotspot has not been configured yet."
        fi
        ;;
      *)
        echo "Usage: gsm-hotspot [on|off|toggle|status|setup]" >&2
        exit 2
        ;;
    esac
  '';
}
