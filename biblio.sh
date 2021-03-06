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
            $( rm -f $depot )
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
    if [[ $2 == --inclure_perdus ]] ; then
        awk -F'%' '{ if( $1 != "") { printf "%s :: [ %-10s ] \"%s\"", $1, $4, $3 ; if( $5 == "<<PERDU>>" ) { printf " %s\n", $5 } else { printf "\n" }  } }' $depot
    else
        awk -F'%' '{ if( $1 != "" && $5 != "<<PERDU>>" ) { printf "%s :: [ %-10s ] \"%s\"\n", $1, $4, $3 } }' $depot
    fi

    return $(( $# - 1 ))
}

function emprunter {
    if [[ "$#" != 5 ]] ; then
        >&2 echo "Nombre incorrect d'arguments"
        exit 1
    fi

    if [[ $( trouver $depot "$4" ) ]] ; then
        >&2 echo "livre avec meme titre deja emprunte"
        exit 1
    fi

    printf "%s%%" "$2" "$3" "$4" "$5" >> $depot
    $( sort $depot -o $depot )

    return $(( $# - 1 ))
}

function emprunteur {
    if [[ "$#" != 2 ]] ; then
        >&2 echo "Nombre incorrect d'arguments"
        exit 1
    fi

    emprunteur=$( awk -F'%' -v str="$2"  '{ if( $3 == str ) { print $1 } }' $depot )

    if [[ "$emprunteur" = "" ]] ; then
        >&2 echo "Aucun livre emprunte $2"
        exit 1
    fi

    echo $emprunteur

    return $(( $# - 1 ))
}

function trouver {
    if [[ "$#" != 2 ]] ; then
        >&2 echo "Nombre incorrect d'arguments"
        exit 1
    fi

    awk -F'%' -v str="$2" '{ if( match(tolower($3), tolower(str) ) ) { print $3 } }' $depot

    return $(( $# - 1 ))
}

function emprunts {
    if [[ "$#" != 2 ]] ; then
        >&2 echo "Nombre incorrect d'arguments"
        exit 1
    fi

    awk -F'%' -v str="$2"  '{ if( $1 == str ) { print $3 } }' $depot

    return $(( $# - 1 ))
}

function rapporter {
    if [[ "$#" != 2 ]] ; then
        >&2 echo "Nombre incorrect d'arguments"
        exit 1
    fi

    awk -F'%' -v str="$2" '{ if( str != $3 ) { print $0 } }' $depot > $depot.tmp && mv $depot.tmp $depot
    $( sort $depot -o $depot )


    if [[ $( diff $depot.tmp $depot ) == "" ]] ; then
        >&2 echo "Aucun livre avec le titre $2"
        exit 1
    fi
    return $(( $# - 1 ))
}

function indiquer_perte {
    awk -F'%' -v str="$2" 'BEGIN{FS=OFS="%"} { if( $3 == str && $5 != "<<PERDU>>") { printf "%s<<PERDU>>\n", $0 } else { printf "%s\n", $0 } }' $depot > $depot.tmp && mv $depot.tmp $depot
    return $(( $# - 1 ))
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
if [[ $1 == --depot*  ]] ; then 
    depot=$( echo $1 | sed -e 's/^[^=]*=//g' )

    if [ ! -f $depot ] && [ $2 != "init" ] ; then
        >&2 echo "$depot n'existe pas"
        exit 1
    fi
    shift 1
fi
depot=${depot:=.biblio.txt}  # Depot par defaut = .biblio.txt

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


