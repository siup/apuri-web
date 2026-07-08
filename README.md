# APURI — apuri.pl

Statyczna strona główna dla domeny apuri.pl z wdrożeniem Docker na VPS i CI/CD przez GitHub Actions.

## Struktura

```
.
├── index.html              # Landing page (publiczny)
├── protected/
│   ├── planner/index.html  # Chroniony placeholder Planner
│   └── stormbot/index.html # Chroniony placeholder Stormbot
├── docker/
│   └── nginx.conf          # Konfiguracja Nginx w kontenerze
├── Dockerfile
├── docker-compose.yml      # Stack: nginx-proxy + TLS + apuri-web
├── .github/workflows/deploy.yml
└── DEPLOY.md               # Instrukcja wdrożenia na VPS
```

## Architektura

- **nginx-proxy** + **acme-companion** — reverse proxy z automatycznym Let's Encrypt
- **apuri-web** — kontener Nginx ze stroną statyczną
- `/planner/` i `/stormbot/` — chronione Basic Auth (hasło tylko na serwerze, plik `secrets/htpasswd`)

## Lokalny podgląd

```bash
docker build -t apuri-web .
docker run --rm -p 8080:80 apuri-web
# Otwórz http://localhost:8080
```

Bez pliku htpasswd chronione ścieżki zwrócą błąd — to normalne lokalnie.

## Wdrożenie

Szczegółowa instrukcja: [DEPLOY.md](DEPLOY.md)

Skrót:

1. Skonfiguruj VPS (Docker, DNS, `.env`, `secrets/htpasswd`)
2. Ustaw sekrety GitHub Actions (`VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`) i zmienną `DEPLOY_TO_VPS=true`
3. Push na `main` — reszta dzieje się automatycznie

## Styl marki

- ciemne tło: grafit / granat
- akcent: mięta + chłodny fiolet
- klimat: prywatne laboratorium, technologia, spokój
- tekst: oszczędny, bez zdradzania szczegółów projektów
