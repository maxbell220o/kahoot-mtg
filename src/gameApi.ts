import { supabase } from "./supabase";
import type { Quiz } from "./types";

export interface SavedQuiz extends Quiz {
  id: string;
}

export interface TeacherGameState {
  code: string;
  status: "waiting" | "question" | "finished";
  current_question: number;
  question_count: number;
  players: { name: string; score: number }[];
}

export interface PublicGameState {
  title: string;
  status: "waiting" | "question" | "finished";
  current_question: number;
  question_count: number;
  question: { prompt: string; answers: [string, string, string, string] } | null;
  score: number;
  has_answered: boolean;
  is_correct: boolean | null;
  leaderboard: { name: string; score: number }[] | null;
}

export interface DisplayGameState {
  code: string;
  title: string;
  status: "waiting" | "question" | "finished";
  current_question: number;
  question_count: number;
  question: { prompt: string; answers: [string, string, string, string] } | null;
  players: { name: string; score: number }[];
}

function client() {
  if (!supabase) {
    throw new Error("Supabase ist nicht konfiguriert. Bitte prüfe die Umgebungsvariablen.");
  }
  return supabase;
}

export async function loadSavedQuizzes(): Promise<SavedQuiz[]> {
  const { data, error } = await client()
    .from("quizzes")
    .select("id,title,questions")
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data as SavedQuiz[];
}

export async function saveQuiz(quiz: Quiz, ownerId: string, quizId?: string): Promise<SavedQuiz> {
  const query = client().from("quizzes");
  const { data, error } = quizId
    ? await query
        .update({ title: quiz.title.trim(), questions: quiz.questions })
        .eq("id", quizId)
        .eq("owner_id", ownerId)
        .select("id,title,questions")
        .single()
    : await query
        .insert({ owner_id: ownerId, title: quiz.title.trim(), questions: quiz.questions })
        .select("id,title,questions")
        .single();
  if (error) throw error;
  return data as SavedQuiz;
}

export async function startGame(quizId: string): Promise<string> {
  const { data, error } = await client().rpc("start_quiz_game", { p_quiz_id: quizId });
  if (error) throw error;
  return data as string;
}

export async function advanceGame(code: string): Promise<void> {
  const { data, error } = await client().rpc("advance_quiz_game", { p_code: code });
  if (error) throw error;
  void data;
}

export async function getTeacherGameState(code: string): Promise<TeacherGameState> {
  const { data, error } = await client().rpc("get_teacher_game_state", { p_code: code });
  if (error) throw error;
  return data as TeacherGameState;
}

export async function getDisplayGameState(code: string): Promise<DisplayGameState> {
  const { data, error } = await client().rpc("get_public_quiz_display", { p_code: code });
  if (error) throw error;
  return data as DisplayGameState;
}

export async function joinGame(code: string, name: string): Promise<{ player_id: string; title: string }> {
  const { data, error } = await client().rpc("join_quiz_game", {
    p_code: code,
    p_name: name.trim(),
  });
  if (error) throw error;
  return data as { player_id: string; title: string };
}

export async function getGameState(code: string, playerId: string): Promise<PublicGameState> {
  const { data, error } = await client().rpc("get_quiz_game_state", {
    p_code: code,
    p_player_id: playerId,
  });
  if (error) throw error;
  return data as PublicGameState;
}

export async function submitAnswer(
  code: string,
  playerId: string,
  answerIndex: number,
): Promise<{ is_correct: boolean; score: number }> {
  const { data, error } = await client().rpc("submit_quiz_answer", {
    p_code: code,
    p_player_id: playerId,
    p_answer_index: answerIndex,
  });
  if (error) throw error;
  return data as { is_correct: boolean; score: number };
}
