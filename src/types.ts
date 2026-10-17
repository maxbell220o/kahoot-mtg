export interface QuizQuestion {
  prompt: string;
  answers: [string, string, string, string];
  correctAnswer: number;
}

export interface Quiz {
  title: string;
  questions: QuizQuestion[];
}

export const createEmptyQuestion = (): QuizQuestion => ({
  prompt: "",
  answers: ["", "", "", ""],
  correctAnswer: 0,
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
      question.answers.length !== 4 ||
      !question.answers.every(
        (answer) => typeof answer === "string" && answer.trim() !== "",
      ) ||
      !Number.isInteger(question.correctAnswer) ||
      (question.correctAnswer as number) < 0 ||
      (question.correctAnswer as number) > 3
    ) {
      throw new Error(
        `Frage ${index + 1} braucht einen Text, vier Antworten und eine richtige Antwort.`,
      );
    }

    return {
      prompt: question.prompt,
      answers: [...question.answers] as QuizQuestion["answers"],
      correctAnswer: question.correctAnswer as number,
    };
  });

  return { title: candidate.title, questions };
}
