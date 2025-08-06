export CALENDAR_ICON="􀒎"

sf_symbol_for() {
  local input="$1"
  case "$input" in
    cloud.bolt.fill) echo "􀇓" ;;
    cloud.bolt.rain.fill) echo "􀇟" ;;
    cloud.drizzle.fill) echo "􀇅" ;;
    cloud.fill) echo "􀇃" ;;
    cloud.fog.fill) echo "􀇋" ;;
    cloud.hail.fill) echo "􀇍" ;;
    cloud.heavyrain.fill) echo "􀇉" ;;
    cloud.moon.fill) echo "􀇛" ;;
    cloud.moon.rain.fill) echo "􀇝" ;;
    cloud.rain.fill) echo "􀇇" ;;
    cloud.sleet.fill) echo "􀇑" ;;
    cloud.snow.fill) echo "􀇏" ;;
    cloud.sun.fill) echo "􀇕" ;;
    cloud.sun.rain.fill) echo "􀇗" ;;
    moon.stars.fill) echo "􀇁" ;;
    sun.max.fill) echo "􀆮" ;;
    wind.snow) echo "􀇦" ;;
    cal) echo "􀉉" ;;
    0) echo "􀃈" ;;
    1) echo "􀃊" ;;
    01) echo "􀃊" ;;
    2) echo "􀃌" ;;
    02) echo "􀃌" ;;
    3) echo "􀃎" ;;
    03) echo "􀃎" ;;
    4) echo "􀃐" ;;
    04) echo "􀃐" ;;
    5) echo "􀃒" ;;
    05) echo "􀃒" ;;
    6) echo "􀃔" ;;
    06) echo "􀃔" ;;
    7) echo "􀃖" ;;
    07) echo "􀃖" ;;
    8) echo "􀃘" ;;
    08) echo "􀃘" ;;
    9) echo "􀃚" ;;
    09) echo "􀃚" ;;
    10) echo "􀔳" ;;
    11) echo "􀔴" ;;
    12) echo "􀔵" ;;
    13) echo "􀔶" ;;
    14) echo "􀔷" ;;
    15) echo "􀔸" ;;
    16) echo "􀔹" ;;
    17) echo "􀔺" ;;
    18) echo "􀔻" ;;
    19) echo "􀔼" ;;
    20) echo "􀔽" ;;
    21) echo "􀔾" ;;
    22) echo "􀔿" ;;
    23) echo "􀕀" ;;
    24) echo "􀕁" ;;
    25) echo "􀕂" ;;
    26) echo "􀕃" ;;
    27) echo "􀕄" ;;
    28) echo "􀕅" ;;
    29) echo "􀕆" ;;
    30) echo "􀕇" ;;
    31) echo "􀘢" ;;
    M) echo "􀂬" ;;
    A) echo "􀂔";;
    S) echo "􀂸" ;;
    D) echo "􀂚" ;;
    E) echo "􀂜" ;;
    *) echo "-" ;;
  esac
}
