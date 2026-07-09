# Wdrożenie apuri.pl na VPS

Instrukcja jednorazowej konfiguracji serwera i ciągłego wdrażania przez GitHub Actions.

## Wymagania

- VPS z Ubuntu/Debian (lub inną dystrybucją z Dockerem)
- Domena `apuri.pl` wskazująca rekordem A na IP VPS
- Opcjonalnie `www.apuri.pl` jako CNAME lub dodatkowy rekord A
- Subdomeny `planner.apuri.pl` i `stormbot.apuri.pl` — rekord A na to samo IP VPS (lub CNAME do `apuri.pl`)
- Konto GitHub z dostępem do repozytorium

## Rekordy DNS

| Host | Typ | Wartość |
|------|-----|---------|
| `@` (apuri.pl) | A | IP VPS |
| `www` | A lub CNAME | IP VPS lub `apuri.pl` |
| `planner` | A lub CNAME | IP VPS lub `apuri.pl` |
| `stormbot` | A lub CNAME | IP VPS lub `apuri.pl` |

## 1. Instalacja Dockera na VPS

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# wyloguj się i zaloguj ponownie, aby grupa docker zadziałała
```

## 2. Klonowanie repozytorium

```bash
sudo mkdir -p /opt/apuri
sudo chown $USER:$USER /opt/apuri
git clone https://github.com/siup/apuri-web.git /opt/apuri
cd /opt/apuri
```

## 3. Konfiguracja środowiska

```bash
cp .env.example .env
nano .env
```

Uzupełnij:

```env
VIRTUAL_HOST=apuri.pl,www.apuri.pl,planner.apuri.pl,stormbot.apuri.pl
LETSENCRYPT_HOST=apuri.pl,www.apuri.pl,planner.apuri.pl,stormbot.apuri.pl
LETSENCRYPT_EMAIL=twoj@email.pl
```

## 4. Hasło Basic Auth (Planner / Stormbot)

Plik haseł **nie jest** w repozytorium — tworzysz go tylko na serwerze:

```bash
mkdir -p secrets
# Zainstaluj apache2-utils jeśli brak htpasswd:
# sudo apt install apache2-utils

htpasswd -Bbc secrets/htpasswd apuri
# wpisz hasło gdy zostaniesz poproszony
```

Ten sam użytkownik/hasło chroni `planner.apuri.pl` oraz link `/stormbot/` na stronie głównej (przekierowanie na subdomenę). Samą subdomenę `stormbot.apuri.pl` można otworzyć bez hasła, jeśli zna się adres.

## 5. Pierwsze uruchomienie

### A) Czysty VPS (bez Nginx na hoście)

```bash
cd /opt/apuri
docker compose pull apuri-web
docker compose up -d
```

Stack `nginx-proxy` + `acme-companion` zajmie porty 80/443 i wystawi certyfikat Let's Encrypt.

### B) VPS z już działającym Nginx (np. inne domeny)

```bash
cd /opt/apuri
docker compose -f docker-compose.host-nginx.yml pull apuri-web
docker compose -f docker-compose.host-nginx.yml up -d

sudo cp deploy/nginx/apuri.pl.conf /etc/nginx/sites-available/apuri.pl
sudo ln -sf /etc/nginx/sites-available/apuri.pl /etc/nginx/sites-enabled/apuri.pl
sudo nginx -t && sudo systemctl reload nginx

# Po ustawieniu DNS na IP VPS:
sudo certbot --nginx -d apuri.pl -d www.apuri.pl -d planner.apuri.pl -d stormbot.apuri.pl
```

Kontener nasłuchuje tylko na `127.0.0.1:8088`, a hostowy Nginx obsługuje TLS i proxy.

## 6. Sekrety i zmienna GitHub Actions

W repozytorium: **Settings → Secrets and variables → Actions**

### Sekrety (New repository secret)

| Sekret | Opis |
|--------|------|
| `VPS_HOST` | IP lub hostname VPS |
| `VPS_USER` | Użytkownik SSH (np. `root` lub `deploy`) |
| `VPS_SSH_KEY` | Prywatny klucz SSH (cała zawartość pliku) |

Port SSH domyślnie `22` (w workflow). Jeśli używasz innego portu, zmień `port:` w `.github/workflows/deploy.yml`.

### Zmienna (Variables → New repository variable)

| Zmienna | Wartość | Opis |
|---------|---------|------|
| `DEPLOY_TO_VPS` | `true` | Włącza automatyczny deploy po każdym pushu na `main` |

Ustaw `DEPLOY_TO_VPS=true` dopiero po skonfigurowaniu VPS i sekretów SSH.

Użytkownik SSH musi mieć dostęp do `/opt/apuri` i uprawnienia do `docker compose`.

## 7. Publiczny pakiet GHCR

Obraz `ghcr.io/siup/apuri-web` musi być **publiczny**, aby VPS mógł go pobrać bez logowania:

1. GitHub → **Packages** → `apuri-web`
2. **Package settings** → **Change visibility** → **Public**

Alternatywnie: na VPS zaloguj się do GHCR (`docker login ghcr.io`) i trzymaj pakiet prywatny.

## 8. Jak działa CI/CD

Każdy push na `main`:

1. GitHub Actions buduje obraz Docker i wypycha do GHCR (`latest` + hash commita)
2. Workflow łączy się po SSH z VPS
3. Na serwerze: `git pull` → `docker compose -f docker-compose.host-nginx.yml pull` → `up -d`

## 9. Weryfikacja

- `https://apuri.pl` — publiczna strona główna
- `https://planner.apuri.pl` — wymaga Basic Auth
- `https://stormbot.apuri.pl` — publiczna (bez hasła, jeśli znasz adres)
- `https://apuri.pl/stormbot/` — wymaga Basic Auth, potem przekierowuje na subdomenę
- Stara ścieżka `/planner/` przekierowuje na subdomenę Planner (301)

## Rozwiązywanie problemów

**Brak certyfikatu SSL**
- Sprawdź, czy DNS wskazuje na VPS (`dig apuri.pl`) — jeśli domena idzie przez Cloudflare, ustaw rekord A na IP VPS i wyłącz proxy (szara chmura) na czas certbota
- Porty 80 i 443 muszą być otwarte w firewallu
- Na VPS z hostowym Nginx: `sudo certbot --nginx -d apuri.pl -d www.apuri.pl -d planner.apuri.pl -d stormbot.apuri.pl`
- Na czystym VPS z docker compose: `docker compose logs acme-companion`

**Subdomena pokazuje stronę główną apuri.pl**
- Na VPS nie ma jeszcze obrazu z konfiguracją subdomen — zrób `git pull` i `docker compose -f docker-compose.host-nginx.yml pull && up -d`
- Hostowy Nginx musi przekazywać subdomeny do kontenera — w `server_name` powinny być wszystkie: `apuri.pl www.apuri.pl planner.apuri.pl stormbot.apuri.pl` (plik `deploy/nginx/apuri.pl.conf`)
- Usuń ewentualne stare, osobne pliki `planner.apuri.pl` / `stormbot.apuri.pl` z `sites-enabled`, jeśli kolidują
- Po zmianie: `sudo nginx -t && sudo systemctl reload nginx`
- Test na VPS: `curl -H "Host: stormbot.apuri.pl" http://127.0.0.1:8088/` — powinien zwrócić HTML Stormbota, nie landing page

**401 Unauthorized na planner.apuri.pl lub /stormbot/**
- Sprawdź, czy istnieje `secrets/htpasswd`
- `docker compose restart apuri-web`

**Deploy z Actions nie działa**
- Zweryfikuj sekrety SSH
- Ręcznie przetestuj: `ssh user@host "cd /opt/apuri && docker compose ps"`

## Podłączenie prawdziwych aplikacji (przyszłość)

Gdy Planner lub Stormbot będą gotowe jako osobne kontenery, w `docker/nginx.conf` zamień serwowanie plików statycznych w bloku `server_name planner.apuri.pl` / `stormbot.apuri.pl` na `proxy_pass` do odpowiedniego backendu.
