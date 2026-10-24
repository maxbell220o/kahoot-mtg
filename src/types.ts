export interface QuizQuestion {
  prompt: string;
  answerType: "multiple-choice" | "text";
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
  answerType: "multiple-choice",
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
    const answerType = question.answerType ?? "multiple-choice";
    if (answerType !== "multiple-choice" && answerType !== "text") {
      throw new Error(`Frage ${index + 1} hat einen ungültigen Antworttyp.`);
    }
    if (
      typeof question.prompt !== "string" ||
      question.prompt.trim() === "" ||
      !Array.isArray(question.answers) ||
      question.answers.length < (answerType === "text" ? 1 : 2) ||
      (answerType === "multiple-choice" && question.answers.length > 6) ||
      !question.answers.every(
        (answer): answer is string => typeof answer === "string" && answer.trim() !== "",
      )
    ) {
      throw new Error(answerType === "text"
        ? `Frage ${index + 1} braucht einen Text und mindestens eine akzeptierte Antwort.`
        : `Frage ${index + 1} braucht einen Text und zwei bis sechs ausgefüllte Antworten.`);
    }

    const answers = question.answers;
    const correctAnswers: unknown[] = Array.isArray(question.correctAnswers)
      ? question.correctAnswers
      : Number.isInteger(question.correctAnswer)
        ? [question.correctAnswer]
        : [];
    if (answerType === "text") {
      if (answers.some((answer) => answer.length > 120)) {
        throw new Error(`Akzeptierte Antworten bei Frage ${index + 1} dürfen höchstens 120 Zeichen lang sein.`);
      }
      if (new Set(answers.map((answer) => answer.trim().toLocaleLowerCase("de"))).size !== answers.length) {
        throw new Error(`Frage ${index + 1} enthält doppelte akzeptierte Antworten.`);
      }
    }
    if (
      answerType === "multiple-choice" && (
      correctAnswers.length === 0 ||
      !correctAnswers.every(
        (answer) =>
          typeof answer === "number" &&
          Number.isInteger(answer) &&
          answer >= 0 &&
          answer < answers.length,
      ) ||
      new Set(correctAnswers).size !== correctAnswers.length
      )
    ) {
      throw new Error(
        `Frage ${index + 1} braucht einen Text, zwei bis sechs Antworten und mindestens eine richtige Antwort.`,
      );
    }
    const validCorrectAnswers = correctAnswers.filter(
      (answer): answer is number => typeof answer === "number",
    );

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
      answerType,
      answers: [...answers],
      correctAnswers: answerType === "text" ? answers.map((_, answerIndex) => answerIndex) : validCorrectAnswers,
      scoringMode,
      timeLimitSeconds: timeLimitSeconds as number,
    };
  });

  return { title: candidate.title, questions };
}
