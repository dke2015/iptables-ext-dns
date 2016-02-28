
if [ "$IPT" = 'iptables' ] ; then
  SERVER='127.0.0.1'
else
  SERVER='::1'
fi
if [ "$PROTOCOL" = "udp" ] ; then
  NSUPDATE_OPT='-w 1 -u'
  DRILL_OPT='-u'
  UPDATE_HEX="efa528000001000000010000096c6f63616c686f73740000060001c00c0001000100000e1000047f000001"
else
  NSUPDATE_OPT="-w 1"
  DRILL_OPT='-t'
  UPDATE_HEX="002b752428000001000000010000096c6f63616c686f73740000060001c00c0001000100000e1000047f000001"
fi

DNSTEST=$(date +DNSTEST-%Y%m%d)

function ipt() {
  ./test-ipt.sh $IPT $DNSTEST $1
}
function begin() {
  ipt "append"
  if [ "$PROTOCOL" = "udp" ] ; then
    $IPT -I INPUT -i lo -p udp --dport 53 -j $DNSTEST
  else
    $IPT -I INPUT -i lo -p tcp --dport 53 -j $DNSTEST
  fi
}
function finish() {
  if [ "$PROTOCOL" = "udp" ] ; then
    $IPT -D INPUT -i lo -p udp --dport 53 -j $DNSTEST
  else
    $IPT -D INPUT -i lo -p tcp --dport 53 -j $DNSTEST
  fi
  ipt "delete"
}
function error() {
  echo "[FAIL] $@"
  $IPT --list-rules $DNSTEST -v
  finish
  exit 1
}
function updateCheck() {
  rule=$1
  $IPT --zero $DNSTEST

  echo $UPDATE_HEX | xxd -r -p | nc $SERVER 53 $NC_OPT

  res=$($IPT --list-rules $DNSTEST -v | grep -- "$rule")
  if [ $? != 0 ] ; then
    echo "[ERR] $res"
    error $rule
  fi
  val=$(echo $res | awk '{print $NF}' )
  if [ ! match_check $val ] ; then
    echo "[FAIL] $res"
    error $rule
  fi
  echo "[PASS] $rule"
}
function check() {
  rule=$1 ; shift
  domain=$1 ; shift
  $IPT --zero $DNSTEST
  drill $domain @$SERVER $DRILL_OPT $@ > /dev/null 2>&1
  res=$($IPT --list-rules $DNSTEST -v | grep -- "$rule ")
  if [ $? != 0 ] ; then
    echo "[ERR] $res"
    error $rule
  fi
  
  val=$(echo $res | awk '{print $NF}' )
  if [ ! match_check $val ] ; then
      echo "[FAIL] $res"
      error $rule
  fi
  echo "[PASS] $rule"
}