#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "########  #### ##    ##    ###    ########     #### ########"
echo "##     ##  ##   ##  ##    ## ##   ##     ##     ##     ##"    
echo "##     ##  ##    ####    ##   ##  ##     ##     ##     ##"   
echo "##     ##  ##     ##    ##     ## ########      ##     ##"   
echo "##     ##  ##     ##    ######### ##   ##       ##     ##"   
echo "##     ##  ##     ##    ##     ## ##    ##      ##     ##"   
echo "########  ####    ##    ##     ## ##     ##    ####    ##"   

echo ""
echo "               ####################### Nginx Installer #######################              "
echo ""
echo ""

if [ ! -d /usr/local/cpanel ]; then
        echo "CPanel was not detected, aborting."
        exit 0
fi

configure_cloudflare()
{ # CLOUDFLARE PATCH
        echo "Configurando Engintron..."

        echo "Adding IP to CloudFlare ..."
        IP_COUNT=$(whmapi1 listips | grep "public_ip:" | cut -d':' -f2 | sed 's/ //' | grep -v "^169.*" | grep -v "^10.*" | grep -v "^192.168.*" | wc -l)
        if [ "$IP_COUNT" -eq 1 ]; then
                IP=$(whmapi1 listips | grep "public_ip:" | cut -d':' -f2 | sed 's/ //' | grep -v "^169.*" | grep -v "^10.*" | grep -v "^192.168.*")
                sed -i '/^set \$PROXY_DOMAIN_OR_IP/d' /etc/nginx/custom_rules
                printf "\nset \$PROXY_DOMAIN_OR_IP \"$IP\";" >> /etc/nginx/custom_rules
        fi
}

configure_dynamic()
{
        echo "Setting up dynamic cache ..."
        sed -i "s/^proxy_cache_valid.*/proxy_cache_valid\t200 30s;/" /etc/nginx/proxy_params_dynamic
}

configure_nocacheoncookie()
{
        sed -i -e '/# DISABLED CACHE IF THERE IS PHP COOKIE/,+4d' /etc/nginx/custom_rules
        printf "\n# DISABLED CACHE IF THERE IS PHP COOKIE\n" >> /etc/nginx/custom_rules
        printf "if (\$http_cookie ~* \".*PHPSESSID.*|.*MoodleSession.*|.*MOODLEID.*|.*laravel_session.*|.*ci_session.*|SSESS.*|symfony|CAKEPHP\") {\n" >> /etc/nginx/custom_rules
        printf "\tset \$CACHE_BYPASS_FOR_DYNAMIC 1;\n" >> /etc/nginx/custom_rules
        printf "\tset \$EXPIRES_FOR_DYNAMIC 0;\n" >> /etc/nginx/custom_rules
        printf "}\n" >> /etc/nginx/custom_rules
}

configure_apachelogs()
{
	CONFFILE="/usr/local/apache/conf/includes/pre_virtualhost_global.conf"
	if [ -f /etc/apache2/conf.d/includes/pre_virtualhost_global.conf ]; then
		CONFFILE="/etc/apache2/conf.d/includes/pre_virtualhost_global.conf"
	fi
	sed -i '/# FIXED START FOR AWSTATS-LOGS ENGINTRON /, / # END FIXED FOR AWSTATS-LOGS ENGINTRON/d' $CONFFILE

cat >> $CONFFILE << EOF
# FIXED START FOR ENGINTRON AWSTATS-LOGS
# NON-PIPED
<IfModule log_config_module>
	LogFormat "%a %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
</IfModule>
# PIPED
<IfModule mod_log_config.c>
	LogFormat "%v:%p %a %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combinedvhost
	LogFormat "%v:%p %a %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
	LogFormat "%v:%p %a %l %u %t \"%r\" %>s %b" common
</IfModule>
# FIN FIX PARA AWSTATS-LOGS ENGINTRON
EOF
	whmapi1 set_tweaksetting key=enable_piped_logs value=1
	service httpd restart
}

configure_template_header_awstats()
{
	mkdir -p /var/cpanel/customizations/includes/
cat > /var/cpanel/customizations/includes/awstats_page_header.html.tt << EOF
<div class="alert alert-warning">
        <span class="glyphicon glyphicon-warning-sign"></span>
        <div class="alert-message">
                <strong>INFO:</strong>
		AWStats does not work properly when the server optimization system (cache) is active. For statistics we recommend implementing <a href="https://analytics.google.com/analytics/web/" target="_blank">Google Analytics</a> on your website
        </div>
</div>
EOF
}

configure_access_log()
{
        sed -i 's/access_log.*\;$/access_log \/var\/log\/nginx\/access.log main;/' /etc/nginx/nginx.conf
        sed -i '/log_format main/d' /etc/nginx/nginx.conf
        sed -i "/access_log.*/i\ \ \ \ log_format main '\$remote_addr - \$remote_user \[\$time_local\] \"\$request\" \$status \$body_bytes_sent \"\$http_referer\" \"\$http_user_agent\" \"\$host\"';" /etc/nginx/nginx.conf
}

fix_logrotate()
{
        sed -i 's/create 640.*/create 640 nginx root/' /etc/logrotate.d/nginx
}

configure_nginxconf()
{
        sed -i 's/client_max_body_size.*/client_max_body_size           128m;/' /etc/nginx/nginx.conf
}

if [ -f /usr/local/src/publicnginx/nginxinstaller ]; then
	echo "NginxCP detected, removing before ..."
	/usr/local/src/publicnginx/nginxinstaller uninstall
	/script/rebuildhttpdconf
	rm -rf /usr/local/src/publicnginx*
fi

cd /; rm -f engintron.sh; wget --no-check-certificate https://raw.githubusercontent.com/engintron/engintron/master/engintron.sh; bash engintron.sh install

echo "Setting..."
configure_cloudflare
configure_dynamic
configure_nocacheoncookie
configure_apachelogs
configure_template_header_awstats
configure_access_log
fix_logrotate
configure_nginxconf

echo "Restarting services ..."
service httpd restart
service nginx restart

echo "Ready!"
