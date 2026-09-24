export const PROFILE_COLUMNS = "id, email, user_type, nickname, whatsapp, campus, major, binusian";

export type OwnProfileRow = {
  id: string;
  email: string;
  user_type: string;
  nickname: string | null;
  whatsapp: string | null;
  campus: string | null;
  major: string | null;
  binusian: string | null;
};
