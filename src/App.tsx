import { useEffect, useRef, useState, type ChangeEvent, type FormEvent } from "react";
import { Link, NavLink, Route, Routes } from "react-router-dom";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "./supabase";
import { createEmptyQuestion, parseQuiz, type Quiz, type QuizQuestion } from "./types";

const starterQuiz: Quiz = {
  title: "Mein erstes Quiz",
  questions: [createEmptyQuestion()],
};

function Layout({ children }: { children: React.ReactNode }) {
  return (
    <div className="app-shell">
      <header className="topbar">
        <Link className="brand" to="/">
          <span className="brand-mark">Q</span>
          <span>Quizzeit</span>
        </Link>
        <nav aria-label="Hauptnavigation">
          <NavLink to="/" end>Mitspielen</NavLink>
          <NavLink to="/lehrer">Lehrerbereich</NavLink>
        </nav>
      </header>
      <main>{children}</main>
      <footer>Ein Quizprojekt für den Unterricht</footer>
    </div>
  );
}

function StudentHome() {
  const [code, setCode] = useState("");
  const [name, setName] = useState("");

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
  }

  return (
    <section className="join-page">
      <div className="hero-copy">
        <span className="eyebrow">Lernen darf Spaß machen</span>
        <h1>Bereit für<br /><span>dein Quiz?</span></h1>
        <p>Gib den Zutrittscode ein, den deine Lehrkraft mit dir geteilt hat.</p>
      </div>
      <form className="panel join-card" onSubmit={handleSubmit}>
        <label htmlFor="join-code">Zutrittscode</label>
        <input
          id="join-code"
          className="code-input"
          autoComplete="one-time-code"
          inputMode="numeric"
          maxLength={8}
          placeholder="123456"
          value={code}
          onChange={(event) => setCode(event.target.value.replace(/\D/g, ""))}
          required
        />
        <label htmlFor="player-name">Dein Name</label>
        <input
          id="player-name"
          autoComplete="nickname"
          maxLength={24}
          placeholder="Wie sollen wir dich nennen?"
          value={name}
          onChange={(event) => setName(event.target.value)}
          required
        />
        <button className="button button-primary button-wide" type="submit">
          Mitspielen
        </button>
        <p className="notice" role="status">
          Die Live-Teilnahme wird im nächsten Schritt mit Supabase verbunden.
        </p>
      </form>
    </section>
  );
}

function validateQuiz(quiz: Quiz): string | null {
  if (!quiz.title.trim()) return "Bitte gib deinem Quiz einen Titel.";
  if (quiz.questions.length === 0) return "Füge mindestens eine Frage hinzu.";
  for (let index = 0; index < quiz.questions.length; index += 1) {
    const question = quiz.questions[index];
    if (!question.prompt.trim()) return `Bitte ergänze den Text von Frage ${index + 1}.`;
    if (question.answers.some((answer) => !answer.trim())) {
      return `Bitte fülle alle vier Antworten bei Frage ${index + 1} aus.`;
    }
  }
  return null;
}

function TeacherEditor({
  onSignOut,
  email,
  authError,
}: {
  onSignOut: () => void;
  email: string | undefined;
  authError: string;
}) {
  const [quiz, setQuiz] = useState<Quiz>(starterQuiz);
  const [message, setMessage] = useState("");
  const fileInput = useRef<HTMLInputElement>(null);

  function updateQuestion(index: number, update: Partial<QuizQuestion>) {
    setQuiz((current) => ({
      ...current,
      questions: current.questions.map((question, questionIndex) =>
        questionIndex === index ? { ...question, ...update } : question,
      ),
    }));
    setMessage("");
  }

  function updateAnswer(questionIndex: number, answerIndex: number, value: string) {
    const question = quiz.questions[questionIndex];
    const answers = [...question.answers] as QuizQuestion["answers"];
    answers[answerIndex] = value;
    updateQuestion(questionIndex, { answers });
  }

  function exportQuiz() {
    const error = validateQuiz(quiz);
    if (error) {
      setMessage(error);
      return;
    }
    const file = new Blob([JSON.stringify(quiz, null, 2)], {
      type: "application/json",
    });
    const url = URL.createObjectURL(file);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${quiz.title.trim().replace(/[^\p{L}\p{N}-]+/gu, "-") || "quiz"}.json`;
    link.click();
    URL.revokeObjectURL(url);
    setMessage("Quizdatei wurde heruntergeladen.");
  }

  async function importQuiz(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    try {
      const imported = parseQuiz(JSON.parse(await file.text()));
      setQuiz(imported);
      setMessage("Quiz wurde erfolgreich geladen.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Die Quizdatei konnte nicht gelesen werden.");
    } finally {
      event.target.value = "";
    }
  }

  return (
    <section className="editor-page">
      <div className="page-heading">
        <div>
          <span className="eyebrow">Lehrerbereich · Prototyp</span>
          <h1>Quiz erstellen</h1>
          <p>Erstelle Fragen mit vier Antwortmöglichkeiten und markiere die richtige.</p>
        </div>
        <div className="toolbar">
          <span className="account-email">{email}</span>
          <button className="button button-secondary" onClick={onSignOut}>
            Abmelden
          </button>
          <input
            ref={fileInput}
            className="visually-hidden"
            type="file"
            accept=".json,application/json"
            onChange={importQuiz}
            aria-label="Quizdatei hochladen"
          />
          <button className="button button-secondary" onClick={() => fileInput.current?.click()}>
            Quiz hochladen
          </button>
          <button className="button button-primary" onClick={exportQuiz}>
            Quiz herunterladen
          </button>
        </div>
      </div>

      {authError && <p className="auth-error" role="alert">{authError}</p>}
      <div className="prototype-banner" role="note">
        <strong>Prototyp:</strong> Anmeldung und gemeinsames Live-Spiel benötigen noch die Verbindung zu Supabase.
        Quizdateien kannst du bereits erstellen, herunterladen und wieder hochladen.
      </div>

      <label className="field-label" htmlFor="quiz-title">Quiz-Titel</label>
      <input
        id="quiz-title"
        className="title-input"
        maxLength={100}
        value={quiz.title}
        onChange={(event) => {
          setQuiz((current) => ({ ...current, title: event.target.value }));
          setMessage("");
        }}
        placeholder="Zum Beispiel: Planeten unseres Sonnensystems"
      />

      <div className="questions-heading">
        <h2>Fragen <span className="count-badge">{quiz.questions.length}</span></h2>
        <button
          className="button button-secondary"
          onClick={() => setQuiz((current) => ({
            ...current,
            questions: [...current.questions, createEmptyQuestion()],
          }))}
        >
          + Frage hinzufügen
        </button>
      </div>

      <div className="question-list">
        {quiz.questions.map((question, questionIndex) => (
          <article className="panel question-card" key={questionIndex}>
            <div className="question-card-heading">
              <h3>Frage {questionIndex + 1}</h3>
              {quiz.questions.length > 1 && (
                <button
                  className="text-button danger-text"
                  onClick={() => setQuiz((current) => ({
                    ...current,
                    questions: current.questions.filter((_, index) => index !== questionIndex),
                  }))}
                  aria-label={`Frage ${questionIndex + 1} entfernen`}
                >
                  Entfernen
                </button>
              )}
            </div>
            <label className="field-label" htmlFor={`prompt-${questionIndex}`}>Frage</label>
            <textarea
              id={`prompt-${questionIndex}`}
              maxLength={300}
              rows={2}
              value={question.prompt}
              onChange={(event) => updateQuestion(questionIndex, { prompt: event.target.value })}
              placeholder="Schreibe deine Frage ..."
            />
            <fieldset className="answers-fieldset">
              <legend>Antwortmöglichkeiten <span>Wähle den Kreis bei der richtigen Antwort.</span></legend>
              <div className="answer-grid">
                {question.answers.map((answer, answerIndex) => (
                  <label className={`answer-option answer-${answerIndex}`} key={answerIndex}>
                    <input
                      type="radio"
                      name={`correct-${questionIndex}`}
                      checked={question.correctAnswer === answerIndex}
                      onChange={() => updateQuestion(questionIndex, { correctAnswer: answerIndex })}
                      aria-label={`Antwort ${answerIndex + 1} als richtig markieren`}
                    />
                    <span className="answer-number">{answerIndex + 1}</span>
                    <input
                      className="answer-input"
                      maxLength={120}
                      value={answer}
                      onChange={(event) => updateAnswer(questionIndex, answerIndex, event.target.value)}
                      placeholder={`Antwort ${answerIndex + 1}`}
                      aria-label={`Antwort ${answerIndex + 1}`}
                    />
                  </label>
                ))}
              </div>
            </fieldset>
          </article>
        ))}
      </div>
      {message && <p className="form-message" role="status">{message}</p>}
    </section>
  );
}

function TeacherLogin() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!supabase) {
      setError("Supabase ist noch nicht konfiguriert. Bitte trage URL und Publishable Key ein.");
      return;
    }

    setError("");
    setSubmitting(true);
    const { error: signInError } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });
    setSubmitting(false);
    if (signInError) setError(signInError.message);
  }

  return (
    <section className="login-page">
      <div>
        <span className="eyebrow">Lehrerbereich</span>
        <h1>Willkommen zurück</h1>
        <p>Melde dich mit deinem Lehrer-Konto an, um Quizze zu erstellen.</p>
      </div>
      <form className="panel login-card" onSubmit={handleSubmit}>
        <label htmlFor="teacher-email">E-Mail-Adresse</label>
        <input
          id="teacher-email"
          type="email"
          autoComplete="username"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          placeholder="name@schule.de"
        />
        <label htmlFor="teacher-password">Passwort</label>
        <input
          id="teacher-password"
          type="password"
          autoComplete="current-password"
          required
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          placeholder="Dein Passwort"
        />
        {error && <p className="auth-error" role="alert">{error}</p>}
        <button className="button button-primary button-wide" type="submit" disabled={submitting}>
          {submitting ? "Anmeldung läuft ..." : "Anmelden"}
        </button>
        <p className="notice">Lehrerkonten werden sicher in Supabase verwaltet.</p>
      </form>
    </section>
  );
}

function TeacherPage() {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [authError, setAuthError] = useState("");

  useEffect(() => {
    if (!supabase) {
      setLoading(false);
      return;
    }

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      setLoading(false);
      setAuthError("");
    });

    void supabase.auth.getSession().then(({ data, error }) => {
      if (error) {
        setAuthError(error.message);
      } else {
        setSession(data.session);
      }
      setLoading(false);
    });

    return () => subscription.unsubscribe();
  }, []);

  async function signOut() {
    if (!supabase) return;
    const { error } = await supabase.auth.signOut();
    if (error) setAuthError(error.message);
  }

  if (loading) {
    return <p className="auth-loading" role="status">Anmeldestatus wird geladen ...</p>;
  }

  if (!session) {
    return (
      <>
        {authError && <p className="auth-error page-auth-error" role="alert">{authError}</p>}
        <TeacherLogin />
      </>
    );
  }

  return <TeacherEditor onSignOut={signOut} email={session.user.email} authError={authError} />;
}

function NotFound() {
  return (
    <section className="empty-page">
      <h1>Diese Seite gibt es nicht.</h1>
      <Link className="button button-primary" to="/">Zur Startseite</Link>
    </section>
  );
}

export default function App() {
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<StudentHome />} />
        <Route path="/lehrer" element={<TeacherPage />} />
        <Route path="*" element={<NotFound />} />
      </Routes>
    </Layout>
  );
}
