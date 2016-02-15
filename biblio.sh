#!/usr/bin/env bash

###################################################
# Fonctions pour debogage et traitement des erreurs.
###################################################


# Pour generer des traces de debogage avec la function debug, il
# suffit de supprimer le <<#>> au debut de la ligne suivante.
#DEBUG=1

function debug {
    [[ -z $DEBUG ]] && return

    echo -n "[debug] "
    for arg in "$@"
    do
        echo -n "'$arg' "
    done
    echo ""
}

function erreur {
    msg=$1

    >&2 echo "*** Erreur: $msg"
    >&2 echo ""

    # On emet le message d'aide si commande fournie invalide.
    # Par contre, ce message doit etre emis sur stdout.
    [[ $msg =~ Commande\ inconnue ]] && aide

    exit 1
}


###################################################
# Fonction d'aide: fournie, pour uniformite.
###################################################

function aide {
    cat <<EOF
NOM
  $0 -- Script pour la gestion de prets de livres

SYNOPSIS
  biblio.sh [--depot=fich] commande [options-commande] [argument...]

COMMANDES
  aide           - Emet la liste des commandes
  emprunter      - Indique l'emprunt d'un livre
  emprunteur     - Emet l'emprunteur d'un livre
  emprunts       - Emet les livres empruntes par quelqu'un
  init           - Cree une nouvelle base de donnees pour gerer des livres empruntes
                   (dans './.biblio.txt' si --depot n'est pas specifie)
  indiquer_perte - Indique la perte du livre indique
  lister         - Emet l'ensemble des livres empruntes
  rapporter      - Indique le retour d'un livre
  trouver        - Trouve le titre complet d'un livre
                   ou les titres qui contiennent la chaine
EOF
}

###################################################
# Fonctions pour manipulation du depot.
#
# Fournies pour simplifier le devoir et assurer au depart un
# fonctionnement minimal du logiciel.
###################################################

function assert_depot_existe {
    depot=$1
    [[ -f $depot ]] || erreur "Le fichier '$depot' n'existe pas!%"
}


function init {
    depot=$1
    if [[ $2 =~ --detruire ]]; then
        nb_options=1
    else
        nb_options=0
    fi

    if [[ -f $depot ]]; then  # -f checks if file exists
        # Depot existe deja
        if [[ $nb_options == 1 ]]; then
            # On le detruit quand --detruire est specifie.
            $( \rm -f $depot )
        else
            erreur "Le fichier '$depot' existe. Si vous voulez le detruire, utilisez 'init --detruire'."
        fi
    fi

    # On 'cree' le fichier vide.
    $( touch $depot )

    return $nb_options
}

###################################################
# Les fonctions pour les diverses commandes de l'application.
#
# A COMPLETER!
###################################################

function lister {
    awk -F'%' '{print $1 " :: [ "$4 " ] \""$3"\"" }' $depot
}


function emprunter {
    $( echo -n $2 >> $depot )
    $( echo -n %  >> $depot )
    $( echo -n $3 >> $depot )
    $( echo -n %  >> $depot )
    $( echo -n $4 >> $depot )
    $( echo -n %  >> $depot )
    $( echo    $5 >> $depot )

    return 4
}

function emprunteur {
    return 0
}

function trouver {
    return 0
}

function emprunts {
    return 0
}

function rapporter {
    return 0
}


function indiquer_perte {
    return 0
}

#######################################################
# Le programme principal
#######################################################

#
# Strategie utilisee pour uniformiser les appels de commande : Une
# commande est mise en oeuvre par une fonction auxiliaire. Cette
# fonction retourne comme statut le nombre d'arguments ou options
# utilisees par la commande.
#
# Ceci permet par la suite, dans l'appelant, de "shifter" les
# arguments et, donc, de verifier si des arguments superflus ont ete
# fournis.
#

# On definit le depot a utiliser.
depot=${depot:=.biblio.txt}  # Depot par defaut = .biblio.txt

debug "On utilise le depot suivant:", $depot


#
# On analyse la commande (= dispatcher).
#
commande=$1
shift
case $commande in
    ''|aide)
        aide
        ;;

    emprunter)
        emprunter $depot "$@"
        shift $?
        ;;

    emprunteur)
        emprunteur $depot "$@"
        shift $?
        ;;

    emprunts)
        emprunts $depot "$@"
        shift $?
        ;;

    indiquer_perte)
        indiquer_perte $depot "$@"
        shift $?
        ;;

    init)
        init $depot $1
        shift $?
        ;;

    lister)
        lister $depot "$@"
        shift $?
        ;;

    rapporter)
        rapporter $depot "$@"
        shift $?
        ;;

    trouver)
        trouver $depot "$@"
        shift $?
        ;;

    *)
        erreur "Commande inconnue: '$commande'"
        ;;
esac

[[ $# == 0 ]] || erreur "Argument(s) en trop: '$@'"


