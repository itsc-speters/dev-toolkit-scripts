#!/bin/bash

# Git Branch Cleanup Tool - Vereinheitlichte Version
# Kann alle Unterverzeichnisse automatisch scannen oder manuell ein Verzeichnis auswählen
# Löscht alle lokalen Branches außer dem aktuellen Branch

# Hilfe anzeigen
show_help() {
    echo "Git Branch Cleanup Tool"
    echo "======================"
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
    echo "Das Skript löscht alle lokalen Git-Branches außer dem aktuellen Branch."
    echo "⚠️  WARNUNG: Alle lokalen Branches werden unwiderruflich gelöscht!"
    echo "🛡️  SCHUTZ: 'main' und 'master' Branches werden niemals gelöscht."
    echo
    echo "Beispiele:"
    echo "  $0                          # Scannt alle Unterverzeichnisse automatisch (mit Bestätigung)"
    echo "  $0 -a /path/to/projects     # Scannt alle Repos unter /path/to/projects (mit Bestätigung)"
    echo "  $0 -y                       # Scannt alle Unterverzeichnisse ohne Bestätigung"
    echo "  $0 -s                       # Manueller Modus für aktuelles Verzeichnis"
    echo "  $0 -s /path/to/single/repo  # Manueller Modus für spezifisches Repo"
    echo "  $0 -s -y /path/to/repo      # Ohne Bestätigung löschen"
    echo
    echo "Terraform-Verzeichnisse (.terraform) werden automatisch ignoriert."
}

# Funktion zum Abrufen aller Branches außer dem aktuellen und geschützten Branches
get_branches_to_delete() {
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    
    if [[ -z "$current_branch" ]]; then
        return 1
    fi
    
    # Alle lokalen Branches außer dem aktuellen und geschützten Branches (main, master)
    git branch | grep -v "^\*" | sed 's/^[[:space:]]*//' | grep -v "^$current_branch$" | grep -v "^main$" | grep -v "^master$"
}

# Automatischer Modus - alle Repositories scannen
auto_mode() {
    local base_dir="$1"
    local auto_confirm="$2"
    
    echo "🧹 Git Branch Cleanup unter: $base_dir"
    echo "📋 Modus: Automatisches Scannen aller Unterverzeichnisse"
    echo "⚠️  WARNUNG: Alle lokalen Branches außer dem aktuellen werden gelöscht!"
    echo

    local repo_count=0
    local cleaned_count=0
    local skipped_count=0
    local error_count=0
    local repos_with_branches=()

    # Erste Schleife: Sammle alle Repositories mit Branches zum Löschen
    echo "🔍 Scanne nach Git-Repositories mit lokalen Branches..."
    while IFS= read -r -d '' gitdir; do
        REPO_DIR="$(dirname "$gitdir")"
        ((repo_count++))
        
        # Wechsle in das Repository-Verzeichnis
        if cd "$REPO_DIR" 2>/dev/null; then
            local current_branch
            current_branch=$(git branch --show-current 2>/dev/null)
            
            if [[ -n "$current_branch" ]]; then
                local branches_to_delete
                branches_to_delete=$(get_branches_to_delete)
                
                if [[ -n "$branches_to_delete" ]]; then
                    local branch_count
                    branch_count=$(echo "$branches_to_delete" | wc -l | tr -d ' ')
                    # Ersetze Newlines durch ein spezielles Trennzeichen für die Array-Speicherung
                    local branches_encoded
                    branches_encoded=$(echo "$branches_to_delete" | tr '\n' '§')
                    repos_with_branches+=("$REPO_DIR|$current_branch|$branch_count|$branches_encoded")
                fi
            fi
            # Zurück zum ursprünglichen Verzeichnis
            cd "$base_dir" || exit 1
        fi
    done < <(find "$base_dir" -type d -name ".git" ! -path "*/.terraform/*" -print0)

    # Zeige gefundene Repositories mit Branches an
    if [[ ${#repos_with_branches[@]} -gt 0 ]]; then
        echo
        echo "📋 Gefundene Repositories mit lokalen Branches (${#repos_with_branches[@]} von $repo_count):"
        echo "=============================================================================="
        for repo_info in "${repos_with_branches[@]}"; do
            IFS='|' read -r repo_path current_branch branch_count branches_encoded <<< "$repo_info"
            echo "📁 $repo_path"
            echo "   🎯 Aktueller Branch: $current_branch"
            echo "   🗑️  Branches zum Löschen ($branch_count):"
            # Dekodiere die Branches (ersetze § wieder durch Newlines)
            local branches
            branches=$(echo "$branches_encoded" | tr '§' '\n')
            while IFS= read -r branch; do
                [[ -n "$branch" ]] && echo "      • $branch"
            done <<< "$branches"
            echo
        done
        
        # Bestätigung erforderlich, außer bei --yes Flag
        if [[ "$auto_confirm" != "true" ]]; then
            echo "⚠️  ${#repos_with_branches[@]} Repository(s) werden bereinigt."
            echo "⚠️  Dies wird alle aufgelisteten Branches unwiderruflich löschen!"
            read -p "Möchten Sie fortfahren? (y/N): " -n 1 -r
            echo
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "❌ Abgebrochen"
                exit 0
            fi
        fi
        
        echo "🚀 Starte Branch-Cleanup..."
        echo
        
        # Zweite Schleife: Lösche Branches in den bestätigten Repositories
        for repo_info in "${repos_with_branches[@]}"; do
            IFS='|' read -r repo_path current_branch branch_count branches_encoded <<< "$repo_info"
            
            # Wechsle in das Repository-Verzeichnis
            if cd "$repo_path" 2>/dev/null; then
                echo "📁 Repository: $repo_path"
                echo "   🎯 Aktueller Branch: $current_branch"
                echo "   🗑️  Lösche $branch_count Branch(es)..."
                
                local deleted_count=0
                local failed_count=0
                
                # Dekodiere die Branches
                local branches
                branches=$(echo "$branches_encoded" | tr '§' '\n')
                
                while IFS= read -r branch; do
                    if [[ -n "$branch" ]]; then
                        echo -n "      • Lösche '$branch'... "
                        if git branch -D "$branch" >/dev/null 2>&1; then
                            echo "✅"
                            ((deleted_count++))
                        else
                            echo "❌"
                            ((failed_count++))
                        fi
                    fi
                done <<< "$branches"
                
                if [[ $failed_count -eq 0 ]]; then
                    echo "   ✅ Alle $deleted_count Branch(es) erfolgreich gelöscht"
                    ((cleaned_count++))
                else
                    echo "   ⚠️  $deleted_count erfolgreich, $failed_count fehlgeschlagen"
                    ((error_count++))
                fi
                echo "-------------------------------"
                
                # Zurück zum ursprünglichen Verzeichnis
                cd "$base_dir" || exit 1
            else
                echo "❌ Kann nicht in Repository-Verzeichnis wechseln: $repo_path"
                ((error_count++))
            fi
        done
    else
        echo "✅ Keine Repositories mit zusätzlichen lokalen Branches gefunden."
    fi

    # Zeige auch andere Repository-Typen an
    echo
    echo "🔍 Überprüfe alle anderen Repositories..."
    while IFS= read -r -d '' gitdir; do
        REPO_DIR="$(dirname "$gitdir")"
        
        # Wechsle in das Repository-Verzeichnis
        if cd "$REPO_DIR" 2>/dev/null; then
            local current_branch
            current_branch=$(git branch --show-current 2>/dev/null)
            
            if [[ -n "$current_branch" ]]; then
                local branches_to_delete
                branches_to_delete=$(get_branches_to_delete)
                
                if [[ -z "$branches_to_delete" ]]; then
                    echo "📁 Repository: $REPO_DIR"
                    echo "   ✅ Nur aktueller Branch ($current_branch) - keine Bereinigung nötig"
                    echo "-------------------------------"
                    ((skipped_count++))
                fi
            else
                echo "📁 Repository: $REPO_DIR"
                echo "   ⚠️  Kein aktueller Branch erkannt - überspringe"
                echo "-------------------------------"
                ((skipped_count++))
            fi
            
            # Zurück zum ursprünglichen Verzeichnis
            cd "$base_dir" || exit 1
        fi
    done < <(find "$base_dir" -type d -name ".git" ! -path "*/.terraform/*" -print0)

    echo "🎉 Automatisches Branch-Cleanup abgeschlossen!"
    echo "📊 Zusammenfassung:"
    echo "   📁 Gefundene Repositories: $repo_count"
    echo "   ✅ Erfolgreich bereinigt: $cleaned_count"
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

    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)

    if [[ -z "$current_branch" ]]; then
        echo "❌ Kein aktueller Branch erkannt"
        exit 1
    fi

    echo "📁 Repository: $(pwd)"
    echo "📋 Modus: Manueller Einzelmodus"
    echo "🎯 Aktueller Branch: $current_branch"

    local branches_to_delete
    branches_to_delete=$(get_branches_to_delete)

    if [[ -z "$branches_to_delete" ]]; then
        echo "✅ Nur aktueller Branch vorhanden - keine Bereinigung nötig"
        exit 0
    fi

    local branch_count
    branch_count=$(echo "$branches_to_delete" | wc -l | tr -d ' ')
    
    echo "🗑️  Branches zum Löschen ($branch_count):"
    while IFS= read -r branch; do
        echo "   • $branch"
    done <<< "$branches_to_delete"
    echo

    # Bestätigung erforderlich, außer bei --yes Flag
    if [[ "$auto_confirm" != "true" ]]; then
        echo "⚠️  Dies wird alle aufgelisteten Branches unwiderruflich löschen!"
        read -p "Branch-Cleanup durchführen? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Abgebrochen"
            exit 0
        fi
    fi

    echo "🚀 Starte Branch-Cleanup..."
    local deleted_count=0
    local failed_count=0
    
    while IFS= read -r branch; do
        if [[ -n "$branch" ]]; then
            echo -n "🗑️  Lösche '$branch'... "
            if git branch -D "$branch" >/dev/null 2>&1; then
                echo "✅"
                ((deleted_count++))
            else
                echo "❌"
                ((failed_count++))
            fi
        fi
    done <<< "$branches_to_delete"

    if [[ $failed_count -eq 0 ]]; then
        echo "✅ Branch-Cleanup erfolgreich abgeschlossen!"
        echo "🎯 $deleted_count Branch(es) gelöscht, aktueller Branch: $current_branch"
    else
        echo "⚠️  Branch-Cleanup teilweise erfolgreich"
        echo "✅ $deleted_count erfolgreich gelöscht"
        echo "❌ $failed_count fehlgeschlagen"
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
