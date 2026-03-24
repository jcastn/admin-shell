# admin-shell
Des nouvelles commandes Linux pour les admins réseau, certaines ont besoin de clés d'API (VirusTotal et AbuseIPDB)


Liste des commandes : 
- `net-check` : Affiche un résumé de la config réseau (interface, adresse MAC, adresse IP publique et locale, passerelle, domaine, dns)
- `sys-check` : Affiche un résumé de l'état du système
- `net-diag` : Test de la connectivité vers différentes destinations (adresse passerelle, serveurs DNS, URLs)
- `net-edit` : Modification de la config IP (domaine, dns, état dhcp)
- `check [file|hash]` : Envoi de fichiers ou de hash sur la plateforme VirusTotal afin de vérifier qu'ils ne comportent pas de virus.
- `check ip` : Envoi d'une IP sur AbuseIPDB afin de vérifier la confiance qui lui est accordée et à quoi sert-elle
- `upbash` : Prise en compte des modifications faites aux fichiers des commandes. 


Pour faire fonctionner le projet :
- les clés d'API doivent être ajoutés dans le fichier `~/.bashrc` avec :
    - `export API_KEY_VIRUSTOTAL="xxxxxxxxx"`
    - `export API_KEY_ABUSEIP="xxxxxxxxx"`
- le fichier `commands.sh` doit être sauvegardé à un emplacement proche de la racine (par exemple `/scripts`)
- le chemin du fichier commands.sh doit être ajouté à la source (~/.bashrc) avec :
    `source /scripts/commands.sh`
- avant la 1ère utilisation, on lance la commande `source /root/.bashrc`.
- La prise en compte des modifications faites au fichier `commands.sh` se fait via la commande `upbash`.


N'hésitez pas à faire des retours sur le projet, il est voué à évoluer :)
Enjoy ! 
