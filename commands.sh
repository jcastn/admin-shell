function upbash() {
        source /scripts/commands.sh
        echo "Mise à jour de la source effectuee !"
}

function greet() {
        echo 'Hi' $1', have a good day !'
}

function get-ip() {
        echo "$(hostname -I)"
}

function net-check() {
        local interface=$(ls /sys/class/net | grep -v "lo")
        local statut=$(cat /sys/class/net/$interface/operstate)
        echo ""
        echo "Resume de la config reseau : "

        echo "- interface :   $interface  (statut : $statut)"

        local mac_address=$(cat /sys/class/net/$interface/address)
        echo "- mac :         $mac_address"

        local ip_publique=$(curl ifconfig.me --silent)
        echo "- ip publique : $ip_publique"

        echo "- ip locale :   $(get-ip)"

        local gateway=$(ip route | grep default | awk '{print $3}')
        echo "- gateway :     $gateway"

        local domain=$(grep -E '^domain' /etc/resolv.conf | awk '{print $2}')
        echo "- domaine :     $domain"

        local dns=$(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}')
        echo "- dns :         $dns"
        echo ""
}

function sys-check(){
        echo "Resume des statistiques du système : "
        echo "- temps d'activité   :  $(uptime -p | sed 's/up //')"

        # utilisation CPU : la valeur $8 (id) correpsond au temps passé idle par le cpu 
        echo "- utilisation CPU    :  $(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')%"
        echo "- processus en cours :  $(ps aux | wc -l)"
        echo "- stockage disque    :  $(df -h | grep /dev/sda1 | awk '{print $4}')o utilisés sur $(df -h | grep /dev/sda1 | awk '{print $2}')o disponibles"
        
        # utilisation RAM : la valeur $3 correspond à l'utilisation et $2 correspond au total
        # Pour le calcul du %, on utilise 'free' sans le '-h' pour avoir des chiffres bruts (octets)
        local ram_stats=$(free -h | grep "Mem:")
        local ram_pourcentage=$(free | grep "Mem:" | awk '{print $3/$2 * 100.0}')
        echo "- utilisation RAM    :  $(echo $ram_stats | awk '{print $3}') utilisés sur $(echo $ram_stats | awk '{print $2}') ($ram_pourcentage%)"
}

function net-diag() {
        local gateway=$(ip route | grep default | awk '{print $3}')
        declare -a hosts_gateway=($gateway)
        declare -a hosts_dns=("8.8.8.8" "1.1.1.1")
        declare -a hosts_url=("youtube.com" "carrefour.fr" "netacad.com" "google.com")
        declare -a types=("Test de la passerelle" "Test des IP" "Test des URLs")
        declare -a categories=(hosts_gateway hosts_dns hosts_url)

        echo ""
        for i in "${!categories[@]}"; do
                declare -n actuelle=${categories[$i]}
                echo "${types[$i]} :"
                for host in "${actuelle[@]}"; do
                        if ping -c 1 "$host" > /dev/null 2>&1; then
                                echo "- $host : ONLINE"
                        else
                                echo "- $host : OFFLINE"
                        fi
                done
                echo ""
        done 
}


function net-edit(){
        local interface=$(ls /sys/class/net | grep -v "lo")
        echo 'Vous voulez modifier '$1' en' $2
        if [ $1 == "domaine" ]; then
                echo "Le nom de domaine est modifié en $2"
                sed -i 's/^domain.*/domain '$2'/' /etc/resolv.conf
                sed -i 's/^search.*/search '$2'/' /etc/resolv.conf
        elif [ $1 == "dns" ]; then
                echo "Le DNS est modifié en $2"
                sed -i 's/^nameserver.*/nameserver '$2'/' /etc/resolv.conf
        elif [ $1 == "dhcp" ]; then
                if [ $2 == "on" ]; then
                        echo "L'ancienne ip locale est : " $(get-ip)
                        #vérification du statut dhcp actuel
                        if ip addr show dev "$interface" | grep -q "dynamic"; then
                                echo "Rien à modifier, l'interface $interface est déjà en mode DHCP."
                        else
                                #nettoyage de l'interface et activation du dhcp
                                ip addr flush dev $interface
                                if dhclient $interface; then
                                        echo "Le DHCP a été activé, la nouvelle IP locale est : "$(get-ip)
                                else 
                                        echo "Le serveur DHCP n'a pas répondu, votre config ip risque de ne pas fonctionner..."
                                fi
                        fi
                elif [ $2 == "off" ]; then
                        echo "L'ancienne ip locale est :" $(get-ip)
                        if ip addr show dev "$interface" | grep -q "dynamic"; then
                                ip addr flush dev ens192
                                dhclient -r ens192
                                echo "Le DHCP a été désactivé, vous n'avez pas d'ip "$(get-ip)
                        else
                                echo "Rien à modifier, l'interface $interface n'est pas en DHCP."
                        fi
                fi
        else 
                echo "Usage de la commande : net-edit [domaine|dns|dhcp] <valeur>"
        fi
}

function check(){
        # Envoi d'un hash sur l'API VirusTotal
        if [ "$1" == "hash" ]; then
                local hash=$(sha256sum "$2" | awk '{print $1}')
                curl -s --request GET \
                  --url "https://www.virustotal.com/api/v3/files/$hash" \
                  --header "x-apikey: $API_KEY_VIRUSTOTAL" | jq '.data.attributes.last_analysis_stats'
                echo "Analyse effectuée sur virustotal.com"
        # Envoi d'un fichier sur l'API VirusTotal
        elif [ "$1" == "file" ]; then
                local file=$2
                local reponse=$(curl -s --request POST \
                  --url "https://www.virustotal.com/api/v3/files" \
                  --header "x-apikey: $API_KEY_VIRUSTOTAL" \
                  --form "file=@$file")

                local id=$(echo "$reponse" | jq -r '.data.id')
                if [ "$id" != "null" ]; then
                        echo "Fichier envoyé à VirusTotal (ID : $id)"
                        echo "Patientez 30 secondes pour les résultats..."
                        sleep 30
            
                        curl -s --request GET \
                          --url "https://www.virustotal.com/api/v3/analyses/$id" \
                          --header "x-apikey: $API_KEY_VIRUSTOTAL" | jq '.data.attributes.stats'
                        echo "Analyse effectuée sur virustotal.com"
                else
                        echo "Erreur lors de l'envoi : $reponse"
                fi
        # Envoi d'une IP sur l'API AbuseIPDB
        elif [ "$1" == "ip" ]; then
                local reponse=$(curl -s -G https://api.abuseipdb.com/api/v2/check \
                  --data-urlencode "ipAddress=$2" \
                  -H "Key: $API_KEY_ABUSEIP" \
                  -H "Accept: application/json")
        
                echo ""
                echo "IP $2 :"
                echo "- Niveau Risque :  $(echo $reponse | jq '.data.abuseConfidenceScore')%"
                echo "- Pays :           $(echo $reponse | jq '.data.countryCode')"
                echo "- FAI :            $(echo $reponse | jq '.data.isp')"
                echo "- Utilisation :    $(echo $reponse | jq '.data.usageType')"
                echo "- Relais Tor :     $(echo $reponse | jq '.data.isTor')"
                echo "- Nbr de Reports : $(echo $reponse | jq '.data.totalReports')"
                echo "- Dernier Report : $(echo $reponse | jq '.data.lastReportedAt')"
                echo "Analyse effectuée sur abuseipdb.com"
                echo ""
        else 
                echo "Usage de la commande : check [hash|file|ip] [/filepath|@IP] "
        fi
}


function backup(){
        if [ "$1" == "create" ]; then
                
                local source="$2"
                local destination='/backups'
                local date=$(date +%Y-%m-%d_%Hh%M)
                local file="backup_$date.bak"

                mkdir -p "$destination"

                tar -czf "$destination/$file" "$source"

                echo 'Une backup du fichier '$2' a été créée dans : /backups ('$date')'

        elif [ "$1" == "restore" ]; then
                local source="$2"
                local destination="$3"
                tar -xzf "$source" -C "$destination"

                if [ $? -eq 0 ]; then
                        echo "La backup $source a été réstaurée dans : $destination"
                else
                        echo "Erreur lors de la restauration."
                fi
        else 
                echo "Usage de la commande : backup [create|restore] chemin/fichier"
        fi
}


function sec-audit-ssh(){
        local config="/etc/ssh/sshd_config"
        echo ""
        echo "Audit de Sécurité SSH : "

        # 1. Vérification du port (Standard ou Modifié)
        local port=$(grep "^Port" "$config" | awk '{print $2}')
        if [[ -z "$port" || "$port" == "22" ]]; then
                echo "[!] Port SSH : 22 - (Défaut - Risque de bruteforce)"
        else
                echo "[V] Port SSH : $port - (Sécurisé)"
        fi

        # 2. Accès Root
        if grep -qi "^PermitRootLogin yes" $config; then
            echo "[!] PermitRootLogin : OUI (Dangereux)"
        else
            echo "[V] PermitRootLogin : NON ou restricted (Sécurisé)"
        fi

        # 3. Authentification par mot de passe
        if grep -qi "^PasswordAuthentication no" $config; then
            echo "[V] PasswordAuthentication : Désactivé (Sécurisé - Clés SSH requises)"
        else
            echo "[!] PasswordAuthentication : Activé (Moins sécurisé)"
        fi

        # 4. Authentification par clé publique
        if grep -qi "^PubkeyAuthentication yes" $config; then
            echo "[V] PubkeyAuthentication : Activée (Bien)"
        else
            echo "[!] PubkeyAuthentication : Désactivée (Attention : Clés SSH non utilisables)"
        fi

        # 5. Version du protocole SSH utilisé (Doit être 2)
        if grep -q "^Protocol 1" $config; then
            echo "[!] Protocole 1 activé (Obsolète et vulnérable)"
        else
            echo "[V] Protocole 2 uniquement (Sécurisé)"
        fi

        # 6. Max Auth Tries (Défaut 6)
        local max_tries=$(grep "^MaxAuthTries" $config | awk '{print $2}')
        if [[ -n "$max_tries" && "$max_tries" -le 3 ]]; then
            echo "[V] MaxAuthTries : $max_tries (Strict - Bien)"
        else
            echo "[ ] MaxAuthTries : ${max_tries:-6} (Standard)"
        fi
}

