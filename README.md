# Quizzeit

Ein Quizsystem für GitHub Pages und Supabase. Lehrkräfte speichern und starten Quizze mit sechsstelligen Zutrittscodes; Schüler treten mit ihrem Namen bei und beantworten Multiple-Choice-Fragen mit zwei bis sechs Antwortmöglichkeiten.

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
      "answers": ["Antwort A", "Antwort B", "Antwort C"],
      "correctAnswers": [0, 2],
      "scoringMode": "normal"
    }
  ]
}
```

Jede Frage enthält zwei bis sechs Antworten. `correctAnswers` enthält die nullbasierten Indizes aller richtigen Antworten. `scoringMode` ist `normal` (bis zu 1.000 Punkte), `double` (bis zu 2.000 Punkte) oder `none`; fehlt der Wert, wird `normal` verwendet. Richtige Antworten erhalten abhängig vom Tempo innerhalb von 30 Sekunden zwischen 100 % und 50 % des Höchstwerts. Ältere Quizdateien mit `correctAnswer` werden beim Import weiter unterstützt.

## GitHub Pages

Die Seite wird ohne GitHub Actions direkt aus dem Ordner `docs/` im `master`-Branch veröffentlicht:

1. Prüfe, dass `.env.local` Project URL und Publishable Key für Supabase enthält.
2. Baue die fertige Website lokal mit `npm run build`. Vite erzeugt alle Dateien in `docs/`, einschließlich eines Fallbacks für Direktlinks wie `/lehrer` und `/tafel/CODE`.
3. Lade den aktualisierten Ordner `docs/` zusammen mit deinen Quellcodeänderungen in den `master`-Branch auf GitHub hoch.
4. Öffne im Repository **Settings → Pages** und wähle bei **Build and deployment → Source** die Option **Deploy from a branch**. Wähle den Branch `master` und den Ordner `/docs`, dann speichere.

GitHub Pages liefert danach den bereits lokal gebauten Inhalt direkt aus `docs/` aus. Nach jeder Änderung am Programm muss erneut `npm run build` ausgeführt und der neue Ordner `docs/` hochgeladen werden. Die GitHub-Actions-Veröffentlichung wird nicht verwendet.

## Lehrer-Anmeldung mit Supabase

Der Lehrerbereich unter `/lehrer` verwendet Supabase Auth mit E-Mail-Adresse und Passwort. Nach der Anmeldung öffnet sich ein Dashboard mit Quiz-Bibliothek, Suche, Import und Startaktionen; der Editor liegt unter `/lehrer/editor`.

1. Erstelle ein Supabase-Projekt und kopiere **Project URL** sowie den **Publishable key** aus den API-Einstellungen.
2. Deaktiviere in Supabase unter **Authentication → Providers → Email** die öffentliche Registrierung. Lege Lehrerkonten selbst über **Authentication → Users → Add user** an und setze für jedes Konto ein Passwort.
3. Für die lokale Entwicklung kopiere `.env.example` nach `.env.local` und trage dort die Project URL und den Publishable key ein. Starte die App danach neu.
4. Baue für GitHub Pages lokal mit `npm run build`. Vite liest die Werte aus `.env.local` und schreibt sie in die statische Browser-App. Der Publishable key darf öffentlich im Browser verwendet werden.
5. In Supabase unter **Authentication → URL Configuration** setze die Site URL auf die veröffentlichte GitHub-Pages-Adresse. Füge diese Adresse zusätzlich zu den Redirect URLs hinzu.
6. Öffne in Supabase **SQL Editor → New query**, kopiere den Inhalt von `supabase/schema.sql` hinein und klicke **Run**. Das richtet Quiz-, Spiel-, Spieler- und Antworttabellen samt Row-Level-Security und sicheren Spiel-Funktionen ein.

Danach kann eine Lehrkraft ein Quiz speichern oder direkt starten. Während des Spiels zeigt die App einen Zutrittscode; Schüler öffnen `/`, geben Code und Namen ein und beantworten die freigegebenen Fragen. Die App fragt den Spielstatus regelmäßig ab. Antworten werden serverseitig ausgewertet; bei Fragen mit mehreren richtigen Antworten müssen alle korrekten Optionen ausgewählt sein.

Der Publishable key ist für den Einsatz im Browser bestimmt. Verwende niemals den `service_role`-Schlüssel in der App oder in GitHub Pages. Die Datei `supabase/schema.sql` ist für ein frisches Projekt gedacht. Führe sie nicht erneut aus, wenn die Tabellen dort bereits angelegt wurden.

## Tafel und separate Steuerkonsole

Die Tafelansicht unter `/tafel/CODE` ist für den Projektor oder ein großes Display gedacht. Sie zeigt den Spielcode, die aktuelle Frage, zwei bis sechs Antwortmöglichkeiten, die Teilnehmenden und am Schluss die Rangliste. Die richtige Antwort wird nicht an die Tafel übertragen.

Die Steuerkonsole liegt unter `/lehrer/konsole/CODE`. Öffne diesen Link auf einem zweiten Gerät und melde dich dort mit dem Lehrer-Konto an. Von dort kann die Lehrkraft das Quiz starten und Frage für Frage weiterschalten. Aus dem Dashboard oder Editor lassen sich Tafel und Steuerkonsole direkt öffnen.

Wenn `schema.sql` bereits im Supabase-Projekt ausgeführt wurde, führe anschließend den Inhalt von `supabase/display-and-console.sql` einmal im SQL Editor aus, damit die Tafel die sichere öffentliche Spielansicht laden kann. Bei einem frischen Projekt: erst `schema.sql`, danach die Migration. Danach veröffentliche die App erneut auf GitHub Pages.

Wenn die bestehende Datenbank schon eingerichtet ist, führe außerdem `supabase/multiple-choice-answers.sql` einmal im SQL Editor aus. Damit werden zwei bis sechs Optionen und mehrere richtige Antworten unterstützt.

Für die zeitabhängige Punktewertung führe bei einer bestehenden Datenbank `supabase/speed-scoring.sql` einmal im SQL Editor aus. Wenn die Datenbank noch nicht auf Mehrfachantworten migriert wurde, führe zuerst `supabase/multiple-choice-answers.sql` aus. Bei einem neuen Projekt enthält das aktuelle `supabase/schema.sql` bereits alle Änderungen; die Migration ist dann nicht nötig. Der Editor erlaubt pro Frage normale, doppelte oder keine Punkte.
