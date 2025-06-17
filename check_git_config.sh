#!/bin/bash

# Hilfe anzeigen
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Git Repository Konfiguration Scanner"
    echo "===================================="
    echo
    echo "Verwendung: $0 [VERZEICHNIS]"
    echo
    echo "Optionen:"
    echo "  VERZEICHNIS  Basis-Verzeichnis zum Scannen (Standard: aktuelles Verzeichnis)"
    echo "  -h, --help   Diese Hilfe anzeigen"
    echo
    echo "Das Skript scannt rekursiv nach Git-Repositories und zeigt deren Konfiguration an:"
    echo "✅ SSH-Verbindungen (empfohlen für Sicherheit)"
    echo "⚠️  HTTPS-Verbindungen (weniger sicher, Passwort erforderlich)"
    echo "❓ Unbekannte Protokolle"
    echo "❌ Repositories ohne Remote"
    echo
    echo "Terraform-Verzeichnisse (.terraform) werden automatisch ignoriert."
    exit 0
fi

BASE_DIR="${1:-.}"

echo "🔍 Scanne Git-Repositories unter: $BASE_DIR (ignoriere .terraform)"
echo

# Suche .git-Verzeichnisse, ignoriere Pfade mit .terraform
while IFS= read -r -d '' gitdir; do
    # Ermittele den Repository-Pfad
    REPO_DIR="$(dirname "$gitdir")"
    
    echo "📁 Repository: $REPO_DIR"

    # Wechsele in das Verzeichnis und hole die Git-Informationen
    (
        cd "$REPO_DIR" || {
            echo "   ⚠️  Konnte nicht in das Verzeichnis wechseln!"
            echo "-------------------------------"
            exit 1
        }

        USER_NAME=$(git config user.name)
        USER_EMAIL=$(git config user.email)
        REMOTE_URL=$(git remote get-url origin 2>/dev/null)
        BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

        # Bestimme Protokoll + Icon
        if [[ "$REMOTE_URL" == git@* || "$REMOTE_URL" == ssh://* ]]; then
            PROTOCOL="SSH"
            ICON="✅"
        elif [[ "$REMOTE_URL" == http* ]]; then
            PROTOCOL="HTTPS"
            ICON="⚠️"
        elif [[ -n "$REMOTE_URL" ]]; then
            PROTOCOL="Unbekannt"
            ICON="❓"
        else
            PROTOCOL="Kein Remote"
            ICON="❌"
        fi

        echo "   👤 user.name     : ${USER_NAME:-<nicht gesetzt>}"
        echo "   📧 user.email    : ${USER_EMAIL:-<nicht gesetzt>}"
        echo "   🌐 remote.origin : $ICON ${REMOTE_URL:-<kein remote>} [$PROTOCOL]"
        echo "   🔄 branch        : ${BRANCH:-<unbekannt>}"
        echo "-------------------------------"
    )
done < <(find "$BASE_DIR" -type d -name ".git" ! -path "*/.terraform/*" -print0)
