export interface QuizQuestion {
  prompt: string;
  answers: string[];
  correctAnswers: number[];
  scoringMode: "normal" | "double" | "none";
  timeLimitSeconds: number;
}

export interface Quiz {
  title: string;
  questions: QuizQuestion[];
}

export const createEmptyQuestion = (): QuizQuestion => ({
  prompt: "",
  answers: ["", "", "", ""],
  correctAnswers: [0],
  scoringMode: "normal",
  timeLimitSeconds: 30,
});

export function parseQuiz(value: unknown): Quiz {
  if (typeof value !== "object" || value === null) {
    throw new Error("Die Datei enthält kein gültiges Quiz.");
  }

  const candidate = value as Record<string, unknown>;
  if (
    typeof candidate.title !== "string" ||
    candidate.title.trim() === "" ||
    !Array.isArray(candidate.questions) ||
    candidate.questions.length === 0
  ) {
    throw new Error("Ein Quiz braucht einen Titel und mindestens eine Frage.");
  }

  const questions = candidate.questions.map((item, index): QuizQuestion => {
    if (typeof item !== "object" || item === null) {
      throw new Error(`Frage ${index + 1} ist ungültig.`);
    }

    const question = item as Record<string, unknown>;
    if (
      typeof question.prompt !== "string" ||
      question.prompt.trim() === "" ||
      !Array.isArray(question.answers) ||
      question.answers.length < 2 ||
      question.answers.length > 6 ||
      !question.answers.every(
        (answer): answer is string => typeof answer === "string" && answer.trim() !== "",
      )
    ) {
      throw new Error(
        `Frage ${index + 1} braucht einen Text und zwei bis sechs ausgefüllte Antworten.`,
      );
    }

    const answers = question.answers;
    const correctAnswers: unknown[] = Array.isArray(question.correctAnswers)
      ? question.correctAnswers
      : Number.isInteger(question.correctAnswer)
        ? [question.correctAnswer]
        : [];
    if (
      correctAnswers.length === 0 ||
      !correctAnswers.every(
        (answer): answer is number =>
          Number.isInteger(answer) &&
          (answer as number) >= 0 &&
          (answer as number) < answers.length,
      ) ||
      new Set(correctAnswers).size !== correctAnswers.length
    ) {
      throw new Error(
        `Frage ${index + 1} braucht einen Text, zwei bis sechs Antworten und mindestens eine richtige Antwort.`,
      );
    }

    const scoringMode = question.scoringMode ?? "normal";
    if (scoringMode !== "normal" && scoringMode !== "double" && scoringMode !== "none") {
      throw new Error(`Frage ${index + 1} hat eine ungültige Punktewertung.`);
    }

    const timeLimitSeconds = question.timeLimitSeconds ?? 30;
    if (
      !Number.isInteger(timeLimitSeconds) ||
      (timeLimitSeconds as number) < 5 ||
      (timeLimitSeconds as number) > 120
    ) {
      throw new Error(`Das Zeitlimit für Frage ${index + 1} muss zwischen 5 und 120 Sekunden liegen.`);
    }

    return {
      prompt: question.prompt,
      answers: [...answers],
      correctAnswers: [...correctAnswers],
      scoringMode,
      timeLimitSeconds: timeLimitSeconds as number,
    };
  });

  return { title: candidate.title, questions };
}
