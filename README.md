# Quizzeit

Ein Quizsystem für GitHub Pages und Supabase. Lehrkräfte speichern und starten Quizze mit sechsstelligen Zutrittscodes; Schüler treten mit ihrem Namen bei und beantworten Fragen mit vier Antwortmöglichkeiten.

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

Der Lehrerbereich unter `/lehrer` verwendet Supabase Auth mit E-Mail-Adresse und Passwort. Nach der Anmeldung öffnet sich ein Dashboard mit Quiz-Bibliothek, Suche, Import und Startaktionen; der Editor liegt unter `/lehrer/editor`.

1. Erstelle ein Supabase-Projekt und kopiere **Project URL** sowie den **Publishable key** aus den API-Einstellungen.
2. Deaktiviere in Supabase unter **Authentication → Providers → Email** die öffentliche Registrierung. Lege Lehrerkonten selbst über **Authentication → Users → Add user** an und setze für jedes Konto ein Passwort.
3. Für die lokale Entwicklung kopiere `.env.example` nach `.env.local` und trage dort die Project URL und den Publishable key ein. Starte die App danach neu.
4. Für GitHub Pages füge im Repository unter **Settings → Secrets and variables → Actions → Variables** zwei Repository-Variablen hinzu: `VITE_SUPABASE_URL` und `VITE_SUPABASE_PUBLISHABLE_KEY`. Der Pages-Workflow übergibt sie beim Build an Vite.
5. In Supabase unter **Authentication → URL Configuration** setze die Site URL auf die veröffentlichte GitHub-Pages-Adresse. Füge diese Adresse zusätzlich zu den Redirect URLs hinzu.
6. Öffne in Supabase **SQL Editor → New query**, kopiere den Inhalt von `supabase/schema.sql` hinein und klicke **Run**. Das richtet Quiz-, Spiel-, Spieler- und Antworttabellen samt Row-Level-Security und sicheren Spiel-Funktionen ein.

Danach kann eine Lehrkraft ein Quiz speichern oder direkt starten. Während des Spiels zeigt die App einen Zutrittscode; Schüler öffnen `/`, geben Code und Namen ein und beantworten die freigegebenen Fragen. Die App fragt den Spielstatus regelmäßig ab. Richtige Antworten werden serverseitig ausgewertet und nicht vor der Antwort an Schüler ausgeliefert.

Der Publishable key ist für den Einsatz im Browser bestimmt. Verwende niemals den `service_role`-Schlüssel in der App oder in GitHub Pages. Die Datei `supabase/schema.sql` ist für ein frisches Projekt gedacht. Führe sie nicht erneut aus, wenn die Tabellen dort bereits angelegt wurden.

## Tafel und separate Steuerkonsole

Die Tafelansicht unter `/tafel/CODE` ist für den Projektor oder ein großes Display gedacht. Sie zeigt den Spielcode, die aktuelle Frage, vier Antwortmöglichkeiten, die Teilnehmenden und am Schluss die Rangliste. Die richtige Antwort wird nicht an die Tafel übertragen.

Die Steuerkonsole liegt unter `/lehrer/konsole/CODE`. Öffne diesen Link auf einem zweiten Gerät und melde dich dort mit dem Lehrer-Konto an. Von dort kann die Lehrkraft das Quiz starten und Frage für Frage weiterschalten. Aus dem Dashboard oder Editor lassen sich Tafel und Steuerkonsole direkt öffnen.

Wenn `schema.sql` bereits im Supabase-Projekt ausgeführt wurde, führe anschließend den Inhalt von `supabase/display-and-console.sql` einmal im SQL Editor aus, damit die Tafel die sichere öffentliche Spielansicht laden kann. Bei einem frischen Projekt: erst `schema.sql`, danach die Migration. Danach veröffentliche die App erneut auf GitHub Pages.
