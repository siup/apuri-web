# Wdrożenie apuri.pl na VPS

Instrukcja jednorazowej konfiguracji serwera i ciągłego wdrażania przez GitHub Actions.

## Wymagania

- VPS z Ubuntu/Debian (lub inną dystrybucją z Dockerem)
- Domena `apuri.pl` wskazująca rekordem A na IP VPS
- Opcjonalnie `www.apuri.pl` jako CNAME lub dodatkowy rekord A
- Konto GitHub z dostępem do repozytorium

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
VIRTUAL_HOST=apuri.pl,www.apuri.pl
LETSENCRYPT_HOST=apuri.pl,www.apuri.pl
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

Ten sam użytkownik/hasło chroni obie ścieżki: `/planner/` i `/stormbot/`.

## 5. Pierwsze uruchomienie

```bash
cd /opt/apuri
docker compose pull apuri-web
docker compose up -d
```

Sprawdź logi:

```bash
docker compose logs -f
```

Po kilku minutach certyfikat Let's Encrypt powinien zostać wystawiony automatycznie.

## 6. Sekrety GitHub Actions

W repozytorium: **Settings → Secrets and variables → Actions → New repository secret**

| Sekret | Opis |
|--------|------|
| `VPS_HOST` | IP lub hostname VPS |
| `VPS_USER` | Użytkownik SSH (np. `root` lub `deploy`) |
| `VPS_SSH_KEY` | Prywatny klucz SSH (cała zawartość pliku) |
| `VPS_PORT` | Port SSH (zwykle `22`) |

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
3. Na serwerze: `git pull` → `docker compose pull apuri-web` → `docker compose up -d`

## 9. Weryfikacja

- `https://apuri.pl` — publiczna strona główna
- `https://apuri.pl/planner/` — wymaga Basic Auth
- `https://apuri.pl/stormbot/` — wymaga Basic Auth

## Rozwiązywanie problemów

**Brak certyfikatu SSL**
- Sprawdź, czy DNS wskazuje na VPS (`dig apuri.pl`)
- Porty 80 i 443 muszą być otwarte w firewallu
- `docker compose logs acme-companion`

**401 Unauthorized na /planner lub /stormbot**
- Sprawdź, czy istnieje `secrets/htpasswd`
- `docker compose restart apuri-web`

**Deploy z Actions nie działa**
- Zweryfikuj sekrety SSH
- Ręcznie przetestuj: `ssh user@host "cd /opt/apuri && docker compose ps"`

## Podłączenie prawdziwych aplikacji (przyszłość)

Gdy Planner lub Stormbot będą gotowe jako osobne kontenery, w `docker/nginx.conf` zamień serwowanie plików statycznych na `proxy_pass` do odpowiedniego backendu.
