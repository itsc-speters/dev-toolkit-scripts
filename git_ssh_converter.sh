#!/bin/bash

# Git Repository SSH Konverter - Vereinheitlichte Version
# Kann alle Unterverzeichnisse automatisch scannen oder manuell ein Verzeichnis auswählen

# Hilfe anzeigen
show_help() {
    echo "Git Repository SSH Konverter"
    echo "============================"
    echo
    echo "Verwendung: $0 [OPTIONEN] [VERZEICHNIS]"
    echo
    echo "Optionen:"
    echo "  -a, --auto      Automatisches Scannen aller Unterverzeichnisse (Standard)"
    echo "  -s, --single    Manueller Modus für ein einzelnes Repository"
    echo "  -y, --yes       Keine Bestätigung erforderlich (Auto- und Single-Modus)"
    echo "  -h, --help      Diese Hilfe anzeigen"
    echo
    echo "Argumente:"
    echo "  VERZEICHNIS     Basis-Verzeichnis zum Scannen oder einzelnes Repository"
    echo "                  (Standard: aktuelles Verzeichnis)"
    echo
    echo "Das Skript konvertiert HTTPS Git-Remotes zu SSH."
    echo "Unterstützte Plattformen:"
    echo "  • GitHub (github.com)"
    echo "  • Azure DevOps (dev.azure.com)"
    echo
    echo "Beispiele:"
    echo "  $0                          # Scannt alle Unterverzeichnisse automatisch (mit Bestätigung)"
    echo "  $0 -a /path/to/projects     # Scannt alle Repos unter /path/to/projects (mit Bestätigung)"
    echo "  $0 -y                       # Scannt alle Unterverzeichnisse ohne Bestätigung"
    echo "  $0 -s                       # Manueller Modus für aktuelles Verzeichnis"
    echo "  $0 -s /path/to/single/repo  # Manueller Modus für spezifisches Repo"
    echo "  $0 -s -y /path/to/repo      # Ohne Bestätigung konvertieren"
    echo
    echo "Terraform-Verzeichnisse (.terraform) werden automatisch ignoriert."
}

# Funktion zur Konvertierung von HTTPS zu SSH
convert_url() {
    local url="$1"
    
    # GitHub
    if [[ "$url" == https://github.com/* ]]; then
        echo "$url" | sed 's|https://github.com/|git@github.com:|'
        return
    fi
    
    # Azure DevOps
    if [[ "$url" == https://*@dev.azure.com/* ]]; then
        # Format: https://user@dev.azure.com/org/project/_git/repo
        # zu: git@ssh.dev.azure.com:v3/org/project/repo
        local without_https="${url#https://}"
        local without_user="${without_https#*@}"
        local org_and_rest="${without_user#dev.azure.com/}"
        local org="${org_and_rest%%/*}"
        local project_and_rest="${org_and_rest#*/}"
        local project="${project_and_rest%%/*}"
        local repo="${project_and_rest##*/_git/}"
        
        echo "git@ssh.dev.azure.com:v3/$org/$project/$repo"
        return
    fi
    
    # Unbekanntes Format - keine Konvertierung
    echo "$url"
}

# Automatischer Modus - alle Repositories scannen
auto_mode() {
    local base_dir="$1"
    local auto_confirm="$2"
    
    echo "🔄 Konvertiere Git-Repositories zu SSH unter: $base_dir"
    echo "📋 Modus: Automatisches Scannen aller Unterverzeichnisse"
    echo

    local repo_count=0
    local converted_count=0
    local skipped_count=0
    local error_count=0
    local https_repos=()

    # Erste Schleife: Sammle alle HTTPS Repositories
    echo "🔍 Scanne nach Git-Repositories mit HTTPS URLs..."
    while IFS= read -r -d '' gitdir; do
        REPO_DIR="$(dirname "$gitdir")"
        ((repo_count++))
        
        (
            cd "$REPO_DIR" || exit 1
            
            REMOTE_URL=$(git remote get-url origin 2>/dev/null)
            
            # Nur HTTPS URLs sammeln
            if [[ "$REMOTE_URL" == https://* ]]; then
                NEW_URL=$(convert_url "$REMOTE_URL")
                
                if [[ "$NEW_URL" != "$REMOTE_URL" ]]; then
                    https_repos+=("$REPO_DIR|$REMOTE_URL|$NEW_URL")
                fi
            fi
        )
    done < <(find "$base_dir" -type d -name ".git" ! -path "*/.terraform/*" -print0)

    # Zeige gefundene HTTPS Repositories an
    if [[ ${#https_repos[@]} -gt 0 ]]; then
        echo
        echo "📋 Gefundene HTTPS Repositories (${#https_repos[@]} von $repo_count):"
        echo "=================================================="
        for repo_info in "${https_repos[@]}"; do
            IFS='|' read -r repo_path old_url new_url <<< "$repo_info"
            echo "📁 $repo_path"
            echo "   🔄 $old_url"
            echo "   ➡️  $new_url"
            echo
        done
        
        # Bestätigung erforderlich, außer bei --yes Flag
        if [[ "$auto_confirm" != "true" ]]; then
            echo "⚠️  ${#https_repos[@]} Repository(s) werden konvertiert."
            read -p "Möchten Sie fortfahren? (y/N): " -n 1 -r
            echo
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "❌ Abgebrochen"
                exit 0
            fi
        fi
        
        echo "🚀 Starte Konvertierung..."
        echo
        
        # Zweite Schleife: Konvertiere die bestätigten Repositories
        for repo_info in "${https_repos[@]}"; do
            IFS='|' read -r repo_path old_url new_url <<< "$repo_info"
            
            (
                cd "$repo_path" || exit 1
                
                echo "📁 Repository: $repo_path"
                echo "   🔄 Konvertiere: $old_url"
                echo "   ➡️  zu:        $new_url"
                
                if git remote set-url origin "$new_url"; then
                    echo "   ✅ Erfolgreich konvertiert"
                    ((converted_count++))
                else
                    echo "   ❌ Fehler beim Konvertieren"
                    ((error_count++))
                fi
                echo "-------------------------------"
            )
        done
    else
        echo "✅ Keine HTTPS Repositories gefunden, die konvertiert werden müssen."
    fi

    # Zeige auch andere Repository-Typen an
    echo
    echo "🔍 Überprüfe alle anderen Repositories..."
    while IFS= read -r -d '' gitdir; do
        REPO_DIR="$(dirname "$gitdir")"
        
        (
            cd "$REPO_DIR" || exit 1
            
            REMOTE_URL=$(git remote get-url origin 2>/dev/null)
            
            # Zeige nicht-HTTPS URLs an
            if [[ "$REMOTE_URL" == git@* ]]; then
                echo "📁 Repository: $REPO_DIR"
                echo "   ✅ Bereits SSH - keine Änderung nötig"
                echo "-------------------------------"
                ((skipped_count++))
            elif [[ "$REMOTE_URL" == https://* ]]; then
                NEW_URL=$(convert_url "$REMOTE_URL")
                if [[ "$NEW_URL" == "$REMOTE_URL" ]]; then
                    echo "📁 Repository: $REPO_DIR"
                    echo "   ⚠️  Unbekanntes HTTPS-Format, überspringe"
                    echo "-------------------------------"
                    ((skipped_count++))
                fi
            elif [[ -n "$REMOTE_URL" ]]; then
                echo "📁 Repository: $REPO_DIR"
                echo "   ⚠️  Nicht-HTTPS URL - überspringe: $REMOTE_URL"
                echo "-------------------------------"
                ((skipped_count++))
            fi
        )
    done < <(find "$base_dir" -type d -name ".git" ! -path "*/.terraform/*" -print0)

    echo "🎉 Automatisches Scannen abgeschlossen!"
    echo "📊 Zusammenfassung:"
    echo "   📁 Gefundene Repositories: $repo_count"
    echo "   ✅ Erfolgreich konvertiert: $converted_count"
    echo "   ⚠️  Übersprungen: $skipped_count"
    echo "   ❌ Fehler: $error_count"
}

# Manueller Modus - einzelnes Repository
single_mode() {
    local repo_dir="$1"
    local auto_confirm="$2"

    if [[ ! -d "$repo_dir/.git" ]]; then
        echo "❌ Kein Git-Repository gefunden in: $repo_dir"
        exit 1
    fi

    cd "$repo_dir" || exit 1

    REMOTE_URL=$(git remote get-url origin 2>/dev/null)

    if [[ -z "$REMOTE_URL" ]]; then
        echo "❌ Kein Remote 'origin' gefunden"
        exit 1
    fi

    echo "📁 Repository: $(pwd)"
    echo "📋 Modus: Manueller Einzelmodus"
    echo "🔍 Aktuelle URL: $REMOTE_URL"

    # Prüfe ob bereits SSH
    if [[ "$REMOTE_URL" == git@* ]]; then
        echo "✅ Bereits SSH - keine Änderung nötig"
        exit 0
    fi

    # Nur HTTPS konvertieren
    if [[ "$REMOTE_URL" != https://* ]]; then
        echo "⚠️  Nicht-HTTPS URL - überspringe"
        exit 0
    fi

    NEW_URL=$(convert_url "$REMOTE_URL")

    if [[ "$NEW_URL" == "$REMOTE_URL" ]]; then
        echo "⚠️  Unbekanntes HTTPS-Format - kann nicht konvertieren"
        exit 1
    fi

    echo "➡️  Neue URL: $NEW_URL"
    echo

    # Bestätigung erforderlich, außer bei --yes Flag
    if [[ "$auto_confirm" != "true" ]]; then
        read -p "Konvertierung durchführen? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Abgebrochen"
            exit 0
        fi
    fi

    if git remote set-url origin "$NEW_URL"; then
        echo "✅ Erfolgreich konvertiert!"
        echo "🔍 Verifikation:"
        git remote get-url origin
    else
        echo "❌ Fehler beim Konvertieren"
        exit 1
    fi
}

# Standardwerte
MODE="auto"
BASE_DIR="."
AUTO_CONFIRM="false"

# Parameter parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -a|--auto)
            MODE="auto"
            shift
            ;;
        -s|--single)
            MODE="single"
            shift
            ;;
        -y|--yes)
            AUTO_CONFIRM="true"
            shift
            ;;
        -*)
            echo "❌ Unbekannte Option: $1"
            echo "Verwende -h oder --help für Hilfe"
            exit 1
            ;;
        *)
            BASE_DIR="$1"
            shift
            ;;
    esac
done

# Verzeichnis zu absolutem Pfad konvertieren
BASE_DIR="$(cd "$BASE_DIR" 2>/dev/null && pwd)" || {
    echo "❌ Verzeichnis nicht gefunden: $BASE_DIR"
    exit 1
}

    case $MODE in
    "auto")
        auto_mode "$BASE_DIR" "$AUTO_CONFIRM"
        ;;
    "single")
        single_mode "$BASE_DIR" "$AUTO_CONFIRM"
        ;;
    *)
        echo "❌ Unbekannter Modus: $MODE"
        exit 1
        ;;
esac
