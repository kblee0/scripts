#!/bin/bash
FWHOME=/export/lupin
SNAT_IP=221.148.247.172
FWNIC=`/sbin/route | grep default | awk '{ print $8; }'`

FW_RULE_LIST=${FWHOME}/bin/port_forwarding.conf
FW_CMD=${FWHOME}/bin/.port_forwarding/port_forwarding_subcmd.sh
FW_CMD_OLD=${FWHOME}/bin/.port_forwarding/port_forwarding_subcmd.old
FW_CMD_LOG=${FWHOME}/bin/.port_forwarding/port_forwarding_last.log
FW_RULE_HIST=${FWHOME}/bin/.port_forwarding/port_forwarding_hist.log
FW_RULE_LAST=${FWHOME}/bin/.port_forwarding/port_forwarding.conf

MOTD_HEAD=${FWHOME}/bin/.port_forwarding/motd.head
MOTD_TAIL=${FWHOME}/bin/.port_forwarding/motd.tail

UPDATE_MOTD=1

IPTABLES=/sbin/iptables

# check root
if [ `whoami` != 'root' ]
then
	echo "Permission denied (you must be root)"
	exit 9
fi

if [ -f "$FW_CMD_OLD" ]
then
        rm -f "$FW_CMD_OLD"
fi

if [ -f "$FW_CMD" ]
then
        mv "$FW_CMD" "$FW_CMD_OLD"
fi

if [ -f "$FW_RULE_LAST" ]
then
        rm -f "$FW_RULE_LAST"
fi

cat $FW_RULE_LIST | awk -v OUT="$FW_CMD" -v CONF="$FW_RULE_LAST" '
BEGIN {
        print "Local Port    Remote IP                  Remote Port   Description" > CONF;
        print "-------------------------------------------------------------------------------" >> CONF;
}
{
        if( match( $0, "^[[:space:]]*([0-9]+)[[:space:]]+([[:graph:]]+)[[:space:]]+([0-9]+)[[:space:]]*([[:graph:]]*.*)[[:space:]]*$", v ) == 0 ) {
                next;
        }
        if( substr( v[1], 1, 1 ) == "#" ) {
                next;
        }
        if( match( v[2], "^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$" ) > 0 ) {
                ip = v[2];
        }
        else {
                cmd = sprintf( "resolveip -s %s", v[2] );
                cmd | getline ip;

                if( match( ip, "^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$" ) == 0 ) {
                        print "not ip";
                        next;
                }
        }

        if( v[4] == "" ) {
                v[4] = sprintf( "%s:%s", ip, v[3] );
        }
        printf "add_port_forwarding %-7s %s:%s \"%s\"\n", v[1], ip, v[3], v[4] >> OUT;

        printf "%-14s%-27s%-14s%s\n", v[1], v[2], v[3], v[4] >> CONF;
}'

if [ ! -f "$FW_CMD" ]
then
        echo "ERROR: $FW_CMD not found"
        exit 1
fi

if [ -f "$FW_CMD_OLD" ]
then
        diff "$FW_CMD" "$FW_CMD_OLD" > /dev/null

        if [ $? -eq 0 ]
        then
                exit 0
        fi
fi

date '+------------------- %Y-%m-%d %H:%M:%S -------------------' >> "$FW_RULE_HIST"
diff "$FW_CMD_OLD" "$FW_CMD" >> "$FW_RULE_HIST"

function add_port_forwarding {
  PORT=$1
  DEST=$2
  COMMENT=$3

  ${IPTABLES} -t nat -A POSTROUTING -s ${SNAT_IP} -p tcp --sport $PORT -j SNAT --to-source $DEST -m comment --comment "$COMMENT"
  ${IPTABLES} -t nat -A PREROUTING -p tcp --dport $PORT -j DNAT --to-destination $DEST -m comment --comment "$COMMENT"
}

${IPTABLES} -P INPUT ACCEPT
${IPTABLES} -P FORWARD ACCEPT
${IPTABLES} -P OUTPUT ACCEPT
${IPTABLES} -t nat -F
${IPTABLES} -t mangle -F
${IPTABLES} -F
${IPTABLES} -X

${IPTABLES} -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT

${IPTABLES} -A INPUT -i lo -j ACCEPT
${IPTABLES} -A INPUT -i $FWNIC -j ACCEPT

${IPTABLES} -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

${IPTABLES} -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
${IPTABLES} -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT

${IPTABLES} -A INPUT -m state --state NEW -m tcp -p tcp -m multiport --dports 80,443 -j ACCEPT

${IPTABLES} -A INPUT -p tcp --dport 21 -j ACCEPT
${IPTABLES} -A OUTPUT -p tcp --sport 21 -j ACCEPT

${IPTABLES} -A INPUT -p tcp --dport 1024:65535 -j ACCEPT
${IPTABLES} -A OUTPUT -p tcp --sport 1024:65535 -j ACCEPT

########## Port forwarding List BEGIN ###########

. "$FW_CMD"

########## Port forwarding List END   ###########

${IPTABLES} -t nat -A POSTROUTING -o $FWNIC -j MASQUERADE

/sbin/service iptables save

${IPTABLES} -nL -v > "$FW_CMD_LOG"

${IPTABLES} -t nat -L >> "$FW_CMD_LOG"

if [ x"$UPDATE_MOTD" = "x1" ]
then
        cat $MOTD_HEAD $FW_RULE_LAST $MOTD_TAIL > /etc/motd
fi
