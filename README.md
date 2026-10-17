# Quizzeit

Ein Quiz-Prototyp für GitHub Pages. Die Oberfläche ist auf Deutsch; Quizfragen haben genau vier Antwortmöglichkeiten und jeweils eine markierte richtige Antwort.

## Lokal starten

```sh
npm install
npm run dev
```

## Quizdateien

Im [Lehrerbereich](/lehrer) lassen sich Quizze erstellen, als JSON herunterladen und wieder hochladen. Das JSON-Format ist:

```json
{
  "title": "Mein Quiz",
  "questions": [
    {
      "prompt": "Welche Antwort ist richtig?",
      "answers": ["Antwort A", "Antwort B", "Antwort C", "Antwort D"],
      "correctAnswer": 0
    }
  ]
}
```

`correctAnswer` ist der nullbasierte Index der richtigen Antwort (0 bis 3).

## GitHub Pages

Der Workflow in `.github/workflows/pages.yml` baut die Anwendung bei jedem Push auf `master` und veröffentlicht sie auf GitHub Pages. In den Repository-Einstellungen muss **Pages → Build and deployment → Source: GitHub Actions** ausgewählt sein. Der Build passt den Asset-Pfad automatisch an den Repository-Namen an und legt eine SPA-Fallback-Seite für `/lehrer` an.

## Lehrer-Anmeldung mit Supabase

Der Lehrerbereich unter `/lehrer` verwendet Supabase Auth mit E-Mail-Adresse und Passwort. Quiz-Speicherung, Zutrittscodes und synchrones Live-Spiel sind noch nicht verbunden.

1. Erstelle ein Supabase-Projekt und kopiere **Project URL** sowie den **Publishable key** aus den API-Einstellungen.
2. Deaktiviere in Supabase unter **Authentication → Providers → Email** die öffentliche Registrierung. Lege Lehrerkonten selbst über **Authentication → Users → Add user** an und setze für jedes Konto ein Passwort.
3. Für die lokale Entwicklung kopiere `.env.example` nach `.env.local` und trage dort die Project URL und den Publishable key ein. Starte die App danach neu.
4. Für GitHub Pages füge im Repository unter **Settings → Secrets and variables → Actions → Variables** zwei Repository-Variablen hinzu: `VITE_SUPABASE_URL` und `VITE_SUPABASE_PUBLISHABLE_KEY`. Der Pages-Workflow übergibt sie beim Build an Vite.
5. In Supabase unter **Authentication → URL Configuration** setze die Site URL auf die veröffentlichte GitHub-Pages-Adresse. Füge diese Adresse zusätzlich zu den Redirect URLs hinzu.

Der Publishable key ist für den Einsatz im Browser bestimmt. Verwende niemals den `service_role`-Schlüssel in der App oder in GitHub Pages. Vor dem Speichern von Quizdaten müssen außerdem passende Datenbanktabellen und Row-Level-Security-Regeln eingerichtet werden.
