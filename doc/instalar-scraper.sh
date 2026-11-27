#!/bin/sh
# Run beside Scraper-atualizado.zip from the SD card. No credentials are included.
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
archive="$base/Scraper-atualizado.zip"
sd=/mnt/SDCARD
stage="$sd/.scraper-instalar-$$"
backup="$sd/Apps/Scraper-backup-$(date +%Y%m%d-%H%M%S)-$$"
log="$sd/Apps/Scraper-instalacao.log"
[ -d "$sd" ] || { echo 'Cartao SD nao encontrado.' >&2; exit 1; }
mkdir -p "$sd/Apps"
: > "$log"
fail() { printf '%s\n' "$*" | tee -a "$log" >&2; exit 1; }
for cmd in unzip sha256sum pgrep; do command -v "$cmd" >/dev/null 2>&1 || fail "Comando ausente: $cmd"; done
[ -f "$archive" ] || fail "Coloque Scraper-atualizado.zip ao lado deste arquivo: $base"
printf '%s  %s\n' 'fe4810b111393ee6b6a5915825f9cde15eba88b41102e96f02764b2a1e51812c' "$archive" | sha256sum -c - >> "$log" 2>&1 || fail 'ZIP nao corresponde a esta versao do instalador.'
if pgrep -f '[s]crap_screenscraper.sh' >/dev/null 2>&1; then fail 'Encerre o Scraper antes de instalar.'; fi
version=$(cat "$sd/System/usr/trimui/crossmix-version.txt" 2>/dev/null || :)
case "$version" in 1.3.0*) ;; *) fail "CrossMix $version nao identificado como v1.3.0; instalacao cancelada.";; esac
for target in "$sd/Apps/Scraper" "$sd/Apps/Scraper/Menu" "$sd/Emus/_Scraper" "$sd/System/usr/trimui/scripts/scraper"; do
    [ ! -L "$target" ] || fail "Destino e link simbolico: $target"
done
mkdir "$stage" || fail 'Nao foi possivel criar a pasta temporaria.'
cleanup() { case "$stage" in "$sd"/.scraper-instalar-[0-9]*) rm -rf -- "$stage";; esac; }
trap cleanup EXIT
trap 'exit 130' HUP INT TERM
unzip -t "$archive" >> "$log" 2>&1 || fail 'ZIP invalido ou incompleto.'
unzip -q "$archive" -d "$stage" >> "$log" 2>&1 || fail 'Falha ao extrair o ZIP.'
src="$stage/Scraper-pacote"
[ -f "$src/Apps/Scraper/launch.sh" ] && [ -f "$src/Emus/_Scraper/screenscraper.sh" ] && [ -f "$src/System/usr/trimui/scripts/scraper/scrap_screenscraper.sh" ] || fail 'Faltam arquivos do Scraper.'
(cd "$src" && sha256sum -c SHA256SUMS.txt) >> "$log" 2>&1 || fail 'Os arquivos extraidos nao conferem.'
mkdir "$backup" || fail 'Nao foi possivel criar backup; nada foi alterado.'
for rel in Apps/Scraper Emus/_Scraper System/usr/trimui/scripts/scraper; do
    if [ -d "$sd/$rel" ]; then
        mkdir -p "$backup/$rel" || fail 'Falha ao preparar backup; nada foi alterado.'
        cp -R "$sd/$rel/." "$backup/$rel/" || fail 'Falha ao copiar backup; nada foi alterado.'
    fi
done
printf 'Backup: %s\n' "$backup" | tee -a "$log"
mkdir -p "$sd/Apps/Scraper/Menu" "$sd/Emus/_Scraper" "$sd/System/usr/trimui/scripts/scraper" || fail "Falha criando diretorios. Backup: $backup"
# A fresh installation gets a credential-free default; existing accounts stay untouched.
if [ ! -e "$sd/System/etc/scraper.json" ]; then
    mkdir -p "$sd/System/etc" || fail "Falha criando configuracao. Backup: $backup"
    printf '%s\n' '{"screenscraper_username":"","screenscraper_password":"","Screenscraper_MediaType":"box-2D","Screenscraper_Region":"us","ScrapeInBackground":"true"}' > "$sd/System/etc/scraper.json.novo" || fail "Falha criando configuracao. Backup: $backup"
    mv "$sd/System/etc/scraper.json.novo" "$sd/System/etc/scraper.json" || fail "Falha gravando configuracao. Backup: $backup"
fi
# Merge menus so custom files survive; existing configuration and art database are untouched.
cp -R "$src/Apps/Scraper/Menu/." "$sd/Apps/Scraper/Menu/" || fail "Falha copiando menu. Backup: $backup"
for name in launch.sh idioma.sh executar-fundo.sh osd-progresso.sh traducao-pt.sql GoTo_Scraper_List.json; do
    cp "$src/Apps/Scraper/$name" "$sd/Apps/Scraper/$name.novo" || fail "Falha em $name. Backup: $backup"
    mv -f "$sd/Apps/Scraper/$name.novo" "$sd/Apps/Scraper/$name" || fail "Falha em $name. Backup: $backup"
done
for name in config.json Scraper.png; do
    [ -e "$sd/Apps/Scraper/$name" ] || cp "$src/Apps/Scraper/$name" "$sd/Apps/Scraper/$name" || fail "Falha em $name. Backup: $backup"
done
for name in config.json scraper_old.sh; do
    [ -e "$sd/Emus/_Scraper/$name" ] || cp "$src/Emus/_Scraper/$name" "$sd/Emus/_Scraper/$name" || fail "Falha em $name. Backup: $backup"
done
[ -e "$sd/System/usr/trimui/scripts/scraper/regions.db" ] || cp "$src/System/usr/trimui/scripts/scraper/regions.db" "$sd/System/usr/trimui/scripts/scraper/regions.db" || fail "Falha em regions.db. Backup: $backup"
cp "$src/Emus/_Scraper/screenscraper.sh" "$sd/Emus/_Scraper/screenscraper.sh.novo" || fail "Falha no iniciador. Backup: $backup"
cp "$src/System/usr/trimui/scripts/scraper/scrap_screenscraper.sh" "$sd/System/usr/trimui/scripts/scraper/scrap_screenscraper.sh.novo" || fail "Falha no coletor. Backup: $backup"
chmod +x "$sd/Apps/Scraper/launch.sh" "$sd/Apps/Scraper/executar-fundo.sh" "$sd/Apps/Scraper/osd-progresso.sh" "$sd/Apps/Scraper/Menu/! Progresso.sh" "$sd/Apps/Scraper/Menu/! Cancelar.sh" "$sd/Emus/_Scraper/screenscraper.sh.novo" "$sd/System/usr/trimui/scripts/scraper/scrap_screenscraper.sh.novo" || fail "Falha nas permissoes. Backup: $backup"
# Change permissions only on actions shipped in this package.
find "$src/Apps/Scraper/Menu" -type f \( -name '*.sh' -o -name '*.launch' \) | while IFS= read -r file; do
    rel=${file#"$src/Apps/Scraper/Menu/"}
    chmod +x "$sd/Apps/Scraper/Menu/$rel" || exit 1
done || fail "Falha nas permissoes do menu. Backup: $backup"
mv -f "$sd/Emus/_Scraper/screenscraper.sh.novo" "$sd/Emus/_Scraper/screenscraper.sh" || fail "Falha no iniciador. Backup: $backup"
mv -f "$sd/System/usr/trimui/scripts/scraper/scrap_screenscraper.sh.novo" "$sd/System/usr/trimui/scripts/scraper/scrap_screenscraper.sh" || fail "Falha no coletor. Backup: $backup"
sync
printf 'Instalado. Backup: %s\n' "$backup" | tee -a "$log"
printf 'System/etc/scraper.json, capas, ROMs e ajustes pessoais foram preservados.\n' | tee -a "$log"
